unit uDBVue;

interface

uses
  SysUtils, Classes, DB, MemDS, {$IFNDEF FPC}DBAccess, MSAccess{$ELSE}sqldb{$ENDIF} , DBGrids ;

type
  TDDBVue = class(TDataModule)
    QColumns: TMSQuery;
  private
    { Private declarations }
  public
     procedure EstablishGrid ( DBG : TDBGrid ; ObjectName : string ) ;
  end;

var
  DDBVue: TDDBVue;

implementation

uses TypInfo , Grids, strutils ;

{$R *.dfm}

procedure TDDBVue.EstablishGrid ( DBG : TDBGrid ; ObjectName : string {Owner:TWinControl{Frame,Form,Panel}) ;
var DSE : TDataSet ;
    s , Name1 : string ;
    i , iStart , iFinish , w , j : integer ;
    O : TStringList ;
    Type1 : char ;
begin

//нужно из view получить order by и применить его в запросе

   DSE := DBG.DataSource.DataSet ;

   O := TStringList ( GetObjectProp ( DSE , 'SQL' , TStringList ) ) ;
   if O = nil then Exit ;

   s := O.Text ;

   iStart := Pos ( '[' , s ) ; // like '%[%|%'
   if 0 = iStart then Exit ;

   iFinish := PosEx ( '|' , s , iStart ) ;
   if 0 = iFinish then Exit ;
   Name1 := copy ( s , iStart + 1 , iFinish - iStart - 1 ) ;

   with QColumns do
   begin
      ParamByName ( 'ObjectAlias' ).AsString := Name1 ;
      Active := true ;
   end ;

   with DSE do
      for i := 0 to Fields.Count - 1 do
      begin
         if QColumns.Locate ( 'name' , Fields[i].FieldName , [] ) then
         begin
            s := QColumns.FieldByName ( 'Caption' ).AsString ;
            Fields[i].Visible := ( s <> '' ) ;
            if s <> '' then
            begin
               Fields[i].DisplayLabel := s ;
               Fields[i].EditMask     := QColumns.FieldByName ( 'Mask' ).AsString ;
               s := QColumns.FieldByName ( 'Width' ).AsString ;
               if TryStrToInt ( s , w ) then
                  Fields[i].DisplayWidth := w
               else
                  if 0 < Pos ( s , '%' ) then ; // ***сделать относительную ширину колонок

               s := QColumns.FieldByName ( 'Type' ).AsString ;
               if s <> '' then
               begin
                  Type1 := s[1] ;

                  if Type1 in ['F' , 'J'] then
                  begin
                     for j := 0 to DBG.Columns.Count - 1 do
                     begin
                        if DBG.Columns[j].FieldName = Fields[i].FieldName then DBG.Columns[j].ButtonStyle := cbsEllipsis ;
                     end ;
                     //QColumns.FieldByName ( 'lookup_object' ).AsString ;
                     //QColumns.FieldByName ( 'lookup_field' ).AsString ;
                  end ;
               end ;
            end ;
         end ;
      end ;
end;

end.
