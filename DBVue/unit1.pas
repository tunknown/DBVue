unit Unit1;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, sqldb, odbcconn, mssqlconn, db, Forms, Controls, Graphics, Dialogs, DBGrids, StdCtrls,  DBCtrls, ExtCtrls, Buttons, ComCtrls
   , SplitterMy, ucForms, common
   , uGridData ;

type
  TSQLQueryHack=class(TSQLQuery);

  { TForm1 }
  TForm1 = class(TForm,ITFForm)
    PMasterDetail: TPanel;
    RDataGrid1: TRDataGrid;
    SMasterDetail: TSplitter;

    procedure DBGDataSingleEditButtonClick(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    GridObjectSchema , GridObjectName , GridObjectClass: string ;
  public
    procedure SetParameters ( {%H-}DM : TDataModule ; Alias : string ; {%H-}Ig : TID ; {%H-}Desc : string ; Selection : boolean ; {%H-}Value : TParams ) ; stdcall ;

    procedure GetIgDesc     ( var Ig : TID ; var Desc : string ) ; stdcall ;

    function  Search        : integer ; stdcall ;
  end;


implementation

uses TypInfo , Variants , windows
    , commonDS
    , uDM ;

{$R *.lfm}

procedure TForm1.DBGDataSingleEditButtonClick(Sender: TObject);
var DBG : TDBGrid ;
    Ig : TID ;
    Desc : string = '' ;
    FIg : TField = nil ;
    FDesc : TField = nil ;
begin
   if not ( Sender is TDBGrid ) then Exit ;

   DBG := TDBGrid ( Sender ) ;

   FDesc := DBG.SelectedField ;

   with DM1.QAttributesRef do
      try
         ParamsClear ( Params ) ;
         ParamByName ( 'ObjectName' ).AsString := GetObjectName ( DBG ) ;
         ParamByName ( 'ColumnName' ).AsString := FDesc.FieldName ;
         if not QInit ( DM1.QAttributesRef ) then Exit ; // вместо TSQLQuery.Filtered, не влияющего на RecordCount

         FIg := DBG.DataSource.DataSet.FieldByName ( FieldByName ( 'IdFieldName' ).AsString ) ;

         // todo имена полей IdFieldNameRef,NameFieldNameRef передать в окно выбора?
         Ig := Null ;
         ucForms.GetObject ( TForm1 , nil , FieldByName ( 'ClassRef' ).AsString , FIg , FDesc , Ig , Desc , nil , true ) ;
      finally
         Close ;
      end ;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   if ( ssCtrl in Shift ) and ( Key = VK_RETURN ) then ModalResult := mrOK ;
end ;

procedure TForm1.SetParameters ( DM : TDataModule ; Alias : string ; Ig : TID ; Desc : string ; Selection : boolean ; Value : TParams ) ; stdcall ;
var PC : TPageControl ;
    TS : TTabSheet ;
    R : TRDataGrid ;
    s : string ;
begin
{   ***   как узнать главный объект грида если в одном классе их несколько
      двоятся параметры действий, т.к.unit не определяется главный объект
      отличать в списке фильтров dbo и свои schema объекты
      список полей и действия только для главного объекта?
      }

   GridObjectClass := Alias ;

   with DM1 , QClassRoot do
   begin
      ParamByName ( 'DB'    ).AsString := SQLConnector.DatabaseName ;
      ParamByName ( 'Class' ).AsString := GridObjectClass ;
      QInit ( QClassRoot ) ;
      GridObjectSchema := FieldByName ( 'TABLE_SCHEMA' ).AsString ;
      GridObjectName   := FieldByName ( 'TABLE_NAME'   ).AsString ;
   end ;

   RDataGrid1.Init ( GridObjectClass , Selection ) ;
   Caption := RDataGrid1.Caption ;

   with DM1 , QMasterDetail do
   begin
      ParamByName ( 'Class' ).AsString := GridObjectClass ;
      if not QInit ( QMasterDetail ) then
      begin
         PMasterDetail.Visible := false ;
         SMasterDetail.Visible := false ;
         RDataGrid1.Align := alClient ;
      end
      else
      begin
         s := FieldByName ( 'Class' ).AsString ;

         with QClasses do
         begin
            ParamByName ( 'Class' ).AsString := s ;
            QInit ( QClasses ) ;
            s := FieldByName ( 'Class' ).AsString ;
         end ;

         PC := TPageControl.Create ( PMasterDetail ) ;
         PC.Parent := PMasterDetail ;
         PC.Align := alClient ;
         while not EOF do
         begin
            TS := PC.AddTabSheet ;
            R := TRDataGrid.Create ( self ) ;
            R.Parent := TS ;
            R.Align := alClient ;
            R.Init ( s , false ) ;
            TS.Caption := R.Caption ;

            Next ;
         end ;
      end ;
   end ;

   if Selection then KeyPreview := true ;
end ;

procedure TForm1.GetIgDesc     ( var Ig : TID ; var Desc : string ) ; stdcall ;
begin
   with DM1.QAttributesAll do
   begin
      if Locate ( 'Class;Method' , VarArrayOf ( [GetQueryInfo ( RDataGrid1.RDBGDM1.DBGDataSingle ){%H-}.Cls , {%H-}'K'] ) , [loCaseInsensitive] ) then
         Ig   := RDataGrid1.RDBGDM1.DBGDataSingle.DataSource.DataSet.FieldByName ( FieldByName ( 'ColumnName' ).AsString ).Value ; // todo получать названия полей из вызывающего грида

      if Locate ( 'Class;Method' , VarArrayOf ( [GetQueryInfo ( RDataGrid1.RDBGDM1.DBGDataSingle ){%H-}.Cls , {%H-}'N'] ) , [loCaseInsensitive] ) then
         Desc := RDataGrid1{%H-}.RDBGDM1.DBGDataSingle.DataSource.DataSet.FieldByName ( FieldByName ( 'ColumnName' ).AsString ).Value ; // todo получать названия полей из вызывающего грида
   end;
end;

function  TForm1.Search        : integer ; stdcall ;
begin
   Result := 0 ;
end;

end.
