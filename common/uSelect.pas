unit uSelect;

interface

uses
   Windows, Classes, Controls, Forms, StdCtrls, Buttons, DBCtrls , db , SysUtils , dialogs, Mask ,
   msaccess , MemDS , MemData, Grids, DBGrids, DBAccess ;

type
  TFSelector = class(TForm)
    DBLLB: TDBGrid;
    BBOK: TBitBtn;
    BBCancel: TBitBtn;
    DSList: TDataSource;
    CBAll: TCheckBox;
    BNew: TButton;
    Edit12: TEdit;
    Button2: TButton;
    MSQuery: TMSQuery;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

    procedure DBLLBDblClick(Sender: TObject);
    procedure CBAllClick(Sender: TObject);
    procedure BNewClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Edit12Change(Sender: TObject);
  private
  public
    p : TParams ;

    Searched : boolean ;
  end ;

function GetSelectionSimple ( MSQ : TMSQuery ; P : TParams ; var Identifier : Variant ; FIdName : string ) : boolean ;
procedure GetSelection ( MSQ : TMSQuery ; P : TParams ; FIg , FDesc : TField ; FIgName , FDescName : string ; Editor : TCustomEdit ; ReadOnly : boolean ) ;
procedure AssignWithFields ( Src , Dst : TMSQuery ) ;

implementation

{$R *.dfm}
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TFSelector.FormCreate(Sender: TObject);
begin
//   DBLLB.Height := 301 ; // иначе слетает
   p := TParams.Create ;
end;

procedure TFSelector.FormDestroy(Sender: TObject);
begin
   p.Free ;
end;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TFSelector.DBLLBDblClick(Sender: TObject);
begin
   if BBOK.Enabled then ModalResult := BBOK.ModalResult ;
end;

procedure TFSelector.CBAllClick(Sender: TObject);
var i : integer ;
begin
   with TMSQuery ( DSList.DataSet ) do
      if CBAll.Checked then
      begin
         p.Assign ( Params ) ;
         for i := 0 to ParamCount - 1 do
            Params[i].Clear ;
      end
      else
         Params.Assign ( p ) ;

   with DSList.DataSet do
      try
         DisableControls ;
         Active := false ;
         Active := true ;
      finally
         EnableControls ;
      end ;
end;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure AssignWithFields ( Src , Dst : TMSQuery ) ;
type TDataSetClass = class of TDataSet ;
var i : integer ;
    cls : TFieldClass ;
    f : TField ;

{    q:tdataset;
    w:TClass;
      w:=Src.ClassType;
      q:=tdataset(w.Create) ;}
begin
   Dst.Assign ( Src ) ; // только дл€ TMSQuery
   for i := 0 to Src.Fields.Count - 1 do
   begin
      cls := TFieldClass ( Src.Fields[i].ClassType ) ;
      f := TField ( cls.Create ( Dst ) ) ;

      with f do
      begin
//         DataType := Src.Fields[i].DataType ; // автоматически при создании от класса
         Name              := Src.Fields[i].Name ;

         Alignment         := Src.Fields[i].Alignment ;
         DisplayLabel      := Src.Fields[i].DisplayLabel ;
         DisplayWidth      := Src.Fields[i].DisplayWidth ;
         EditMask          := Src.Fields[i].EditMask ;
         FieldKind         := Src.Fields[i].FieldKind ;
         FieldName         := Src.Fields[i].FieldName ;
         KeyFields         := Src.Fields[i].KeyFields ;
         Lookup            := Src.Fields[i].Lookup ;
         LookupCache       := Src.Fields[i].LookupCache ;
         LookupDataSet     := Src.Fields[i].LookupDataSet ;
         LookupKeyFields   := Src.Fields[i].LookupKeyFields ;
         LookupResultField := Src.Fields[i].LookupResultField ;
         Origin            := Src.Fields[i].Origin ;
         ReadOnly          := Src.Fields[i].ReadOnly ;
         Size              := Src.Fields[i].Size ;
         Visible           := Src.Fields[i].Visible ;

         DataSet           := Dst ;
      end ;

      if f is TStringField   then TStringField   ( f ).FixedChar     := TStringField   ( Src.Fields[i] ).FixedChar ;
      if f is TDateTimeField then TDateTimeField ( f ).DisplayFormat := TDateTimeField ( Src.Fields[i] ).DisplayFormat ;
      if f is TNumericField  then TNumericField  ( f ).DisplayFormat := TNumericField  ( Src.Fields[i] ).DisplayFormat ;
      if f is TNumericField  then TNumericField  ( f ).EditFormat    := TNumericField  ( Src.Fields[i] ).EditFormat ;

{      with Dst.FieldDefs.AddFieldDef do // не видит Calculated пол€
      begin
         Assign ( Src.FieldDefs[i] ) ;
         CreateField ( Dst , nil , Src.Fields[i].FieldName ) ;
      end ;

      Dst.Fields[i].DisplayLabel := Src.Fields[i].DisplayLabel ;
      Dst.Fields[i].DisplayWidth := Src.Fields[i].DisplayWidth ;
      Dst.Fields[i].Visible      := Src.Fields[i].Visible ;}
   end ;
end;

procedure GetSelection ( MSQ : TMSQuery ; P : TParams ; FIg , FDesc : TField ; FIgName , FDescName : string ; Editor : TCustomEdit ; ReadOnly : boolean ) ;
var fne : TFieldNotifyEvent ;
    SaveNeed , ShowIfNotFound : boolean ;
    i , w : integer ;
begin
   if not assigned ( MSQ ) then raise Exception.Create ( 'Ќе задан источник списка' ) ;
   if    ( (     assigned ( FIg ) and not assigned ( FDesc ) )
      or   ( not assigned ( FIg ) and     assigned ( FDesc ) ) ) then raise Exception.Create ( 'Ќе задан источник сохранени€ данных' ) ;

   SaveNeed := assigned ( FIg ) and ( FIg.DataSet.State in [dsInsert , dsEdit] ) ;

   if SaveNeed then
   begin
      if     assigned ( Editor )
         and ( Editor.Text = '' )
         and Editor.Modified then
      begin
         FDesc.Clear ;
         FIg.Clear ;
         Exit ;
      end ;

      fne := FDesc.OnChange ;
      FDesc.OnChange := nil ;
   end
   else
      fne := nil ;

   try
      ShowIfNotFound :=    not assigned ( FIg )
                        or not SaveNeed //( FIg.DataSet.State = dsBrowse )
                        or ( assigned ( Editor ) and not Editor.Modified and ( FDesc.AsString = Editor.Text ) ) ;

      if not ShowIfNotFound and assigned ( Editor ) then
         with TMSQuery ( MSQ ) do
         begin
            ParamByName ( FDesc.LookupResultField ).AsString := '%' + Editor.Text + '%' ; // им€ параметра должно совпадать с именем требуемого столбца
            Active := false ;
            Active := true ;

            ShowIfNotFound := ( RecordCount <> 1 ) ; // "нашЄл"=ровно одна запись найдена по этому слову

            if SaveNeed and not ShowIfNotFound then
            begin
               FIg.AsString   := MSQ.FieldByName ( FDesc.LookupKeyFields   ).AsString ;
               FDesc.AsString := MSQ.FieldByName ( FDesc.LookupResultField ).AsString ;
            end ;
         end ;

      if ShowIfNotFound then
         with TFSelector.Create ( nil ) do
            try
               AssignWithFields ( MSQ , MSQuery ) ;
//               DSList.DataSet  := MSQ ;
//               DBLLB.KeyField  := FName.LookupKeyFields ;
//               DBLLB.ListField := FName.LookupResultField ;

               BBOK.Enabled := SaveNeed ;

               if FDesc.DisplayLabel <> FDesc.FieldName then Caption := FDesc.DisplayLabel ;

               with MSQuery do
               begin
                  if assigned ( p ) then Params.AssignValues ( P ) ;
//                  ParamByname ( FDesc.LookupResultField ).Clear ;
                  Active := false ;
                  Active := true ;

                  Locate ( 'Ig' , FIg.AsString , [loCaseInsensitive] ) ; // if Assigned ( FId ) and ( FId.AsString <> '' ) then DBLLB.KeyValue := FId.AsString ;
               end ;

               BNew.Visible := not ReadOnly ;

               w := 0 ;

               for i := 0 to DBLLB.Columns.Count - 1 do
                  if DBLLB.Columns[i].Visible then w := w + DBLLB.Columns[i].Width ;

               if w < Screen.Width then {TFSelector.}Width := w else Width := Screen.Width ;

               if ( ShowModal = mrOK ) and SaveNeed then
               begin
                  if assigned ( FDesc.LookupDataSet ) and ( FDesc.LookupDataSet.Name = MSQuery.Name ) then
                  begin
                     if ( FIgName   = '' ) and ( FDesc.LookupKeyFields   <> '' ) then FIgName   := FDesc.LookupKeyFields ;
                     if ( FDescName = '' ) and ( FDesc.LookupResultField <> '' ) then FDescName := FDesc.LookupResultField ;
                  end ;
                  FIg.AsString   := MSQuery.FieldByName ( FIgName   ).AsString ;
                  FDesc.AsString := MSQuery.FieldByName ( FDescName ).AsString ;
               end ;
            finally
               MSQuery.Active := false ; // хот€ и так будет закрыт при освобождении формы
               Free ;
            end ;
   finally
      if assigned ( fne ) then FDesc.OnChange := fne ;
   end ;
end ;

function GetSelectionSimple ( MSQ : TMSQuery ; P : TParams ; var Identifier : Variant ; FIdName : string ) : boolean ;
var i , w : integer ;
begin
   with TFSelector.Create ( nil ) do
      try
         AssignWithFields ( MSQ , MSQuery ) ;

         with MSQuery do
         begin
            if assigned ( P ) then Params.AssignValues ( P ) ;

            Active := false ;
            Active := true ;
         end ;

         BNew.Visible := false ;

         w := 0 ;

         for i := 0 to DBLLB.Columns.Count - 1 do
            if DBLLB.Columns[i].Visible then w := w + DBLLB.Columns[i].Width ;

         if w < Screen.Width then {TFSelector.}Width := w else Width := Screen.Width ;

         Result := ( ShowModal = mrOK ) ;
         if Result then Identifier := MSQuery.FieldByName ( FIdName ).Value ;
      finally
         Free ;
      end ;
end ;

procedure TFSelector.BNewClick(Sender: TObject);
//var Value : string ;
begin
{   Value := Edit12.Text ;
   if not InputQuery ( Caption , '¬ведите название' , Value ) then Exit ;

   DSList.DataSet.Insert ;
   DSList.DataSet.FieldByName ( DBLLB.ListField ).AsString := Value ;
   DSList.DataSet.Post ;
   DSList.DataSet.Refresh ;

   Edit12.Text := Value ;
   Button2.OnClick ( Sender ) ;}
end ;

procedure TFSelector.Button2Click(Sender: TObject);
//var Options : TLocateExOptions ;
//    s : string ;
begin
{   Options := [lxCaseInsensitive , lxPartialCompare] ;

   if Searched then
   begin
      Options := Options + [lxNext] ;
      s := 'Ѕольше ничего не найдено' ;
   end
   else
      s := 'Ќичего не найдено' ;

   if TMemDataSet ( DSList.DataSet ).LocateEx ( DBLLB.ListField , Edit12.Text , Options ) then
   begin
      Searched := true ;
      DBLLB.KeyValue := DBLLB.ListSource.DataSet.FieldByName ( DBLLB.KeyField ).AsString ;
   end
   else
      ShowMessage ( s ) ;}
end ;

procedure TFSelector.Edit12Change(Sender: TObject);
begin
   Searched := false ;
end;

end.
