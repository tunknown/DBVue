unit uGridData;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, ExtCtrls, DBGrids, DBCtrls, SQLDB, DB,
   BufDataset, Graphics, Buttons, Grids, SplitterMy, uDBGTree, uDBGMD, uDBNav;

type

   { TRDataGrid }
   TSQLQueryHack = class ( TSQLQuery ) ;
   TCustomGridHack = class ( TCustomGrid ) ; // FreePascal "-CR" (verify method calls) compiler option must be off even in DEBUG mode
   TDBNavigatorHack = class ( TDBNavigator ) ;

   TRDataGrid = class(TFrame)
      BDActions: TBufDataset;
      BBAction: TBitBtn;
      DBLCBActionsSingle: TDBLookupComboBox;
      DBNSingle1: TDBNavigator;
      DSMain: TDataSource;
      DSActions: TDataSource;
      FrameDBGTree1: TFrameDBGTree;
      Panel1: TPanel;
      PControlSingle: TPanel;
      PDataSingle: TPanel;
      PErrorSingle: TPanel;
      PFilterSingle: TPanel;
      PSingle: TPanel;
      RDBGDM1: TRDBGDM;
      RDBN: TRDBNavigator;
      SErrorSingle: TSplitter;
      SFilterSingle: TSplitter;
      SQLQMain: TSQLQuery;

      // вычищать обработчики этого модуля на объекты из вложенных подфреймов из .lfm конечной формы, иначе TReader при загрузке формы не сможет найти свойство с ошибкой "Invalid value for property"
      procedure BBActionClick(Sender: TObject);
      procedure DBGDataSingleDblClick        ( Sender : TObject ) ;
      procedure DBLCBActionsSingleSelect(Sender: TObject);

      procedure DSFilterDataChange           ( Sender : TObject ; {%H-}Field : TField ) ;
      procedure DSMainStateChange            ( Sender : TObject ) ;
      procedure SQLQFilterAfterEdit          ( {%H-}DataSet : TDataSet ) ;
      procedure SQLQMainBeforePost           ( DataSet : TDataSet ) ;
   private
   public
      procedure Init ( GridObject : string ; IsSelectable : boolean ) ;
      procedure Refresh ;

      procedure ToggleError ( C : TColor ) ;
   end;


implementation

uses TypInfo , Variants , dialogs , stdctrls
   , common , commonDS , commonCTRL , ucForms
   , uDM , FUIFast , uFltSngl ;

{$R *.lfm}

procedure TRDataGrid.DBGDataSingleDblClick(Sender: TObject);
var F : TForm ;
begin
   F := TForm ( GetParentRoot ( nil , TForm ) ) ;
   F.ModalResult := mrOK ;
end ;

procedure TRDataGrid.DSFilterDataChange(Sender: TObject; Field: TField);
var CanInsert , CanUpdate , CanDelete : boolean ;
    GridObject , s : string ;
begin
   with FrameDBGTree1.SQLQ do
   begin
      GridObject := FieldByName ( 'Class' ).AsString ; // могут различаться, если содержат подклассы через точки
      PControlSingle.Caption := ' ' + FieldByName ( 'Caption' ).AsString ;
      s := 'select*from"dbo".' + FieldByName ( 'TABLE_NAME' ).AsString.QuotedString ( '"' ) ;
   end ;

   if s <> trim ( SQLQMain.SQL.Text ) then // не вызывается при развороте дерева без перехода на другую запись
   begin
      RDBGDM1.DBGDataSingle.DataSource.DataSet.Close ;
      SQLQMain.SQL.Text := s ;

      with DM1.QActions do
      begin
         CanInsert := Locate ( 'Class;Method' , VarArrayOf ( [{%H-}GridObject , {%H-}'I'] ) , [] ) ;
         CanUpdate := Locate ( 'Class;Method' , VarArrayOf ( [{%H-}GridObject , {%H-}'U'] ) , [] ) ;
         CanDelete := Locate ( 'Class;Method' , VarArrayOf ( [{%H-}GridObject , {%H-}'D'] ) , [] ) ;
      end ;

      if CanInsert then
         with DM1.QSQLize do
         begin
            ParamByName ( 'Class'  ).AsString := GridObject ;
            ParamByName ( 'Method' ).AsString := 'I' ;
            QInit ( DM1.QSQLize ) ;
            SQLQMain.InsertSQL.Text := '*'; // bypass readonly check
            Close ;
            RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options - [dgDisableInsert] ;
         end
      else
         RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options + [dgDisableInsert] ;

      if CanUpdate then
      begin
         with DM1.QSQLize do
         begin
            ParamByName ( 'Class'  ).AsString := GridObject ;
            ParamByName ( 'Method' ).AsString := 'U' ;
            QInit ( DM1.QSQLize ) ;
            SQLQMain.UpdateSQL.Text := '*'; // bypass readonly check
            Close ;
         end ;
         RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options + [dgEditing] ;
      end
      {else
         RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options - [dgEditing]} ;

      if CanDelete then
         with DM1.QSQLize do
         begin
            ParamByName ( 'Class'  ).AsString := GridObject ;
            ParamByName ( 'Method' ).AsString := 'D' ;
            QInit ( DM1.QSQLize ) ;
            SQLQMain.DeleteSQL.Text := '*'; // bypass readonly check
            Close ;
            RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options - [dgDisableDelete] ;
         end
      else
         RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options + [dgDisableDelete] ;

      SQLQMain.ReadOnly := not ( CanInsert or CanUpdate or CanDelete ) ;
      if SQLQMain.ReadOnly then RDBGDM1.DBGDataSingle.Options := RDBGDM1.DBGDataSingle.Options - [dgEditing] ;

      QInit ( RDBGDM1.DBGDataSingle ) ;
      TSQLQueryHack ( SQLQMain ).Cursor.FStatementType := stSelect ; // чтобы Edit не выдавал ReadOnly при редактировании запроса с quoted частями нужен костыль; todo перенести в QInit?
      TDBNavigatorHack ( RDBN.DBNSingle ).UpdateButtons ;

      with DM1.QActions do
         try
            Filter := 'Class="" or Class=' + GridObject.QuotedString ; // для точного класса объекта грида или для всех совместимых подкласов?
            Filtered := true ;
            TBufDataset ( DBLCBActionsSingle.ListSource.DataSet ).CopyFromDataset ( DM1.QActions ) ; // копируем все, т.к. IUD может быть несколько
         finally
            Filtered := false ;
         end ;
      QInit ( DBLCBActionsSingle.ListSource.DataSet ) ;

      DBLCBActionsSingle.Text := '' ;
   end ;
end ;

procedure TRDataGrid.DSMainStateChange(Sender: TObject);
var DSsav : TNotifyEvent ;
begin // при добавлении новой записи Master-Detail должен показывать пустые предметы; todo переделать на BeforePost?
   RDBGDM1.DBGDataSingle.SelectedRows.Clear ;

   DBLCBActionsSingle.Enabled := ( RDBGDM1.DBGDataSingle.DataSource.State = dsBrowse ) and not RDBGDM1.DBGDataSingle.DataSource.DataSet.IsEmpty ;

   with DBLCBActionsSingle , TBufDataSet ( ListSource.DataSet ) do
   begin
      case RDBGDM1.DBGDataSingle.DataSource.State of // IUD может быть несколько
         dsBrowse :
            begin
               Filter := 'Method="A"' ;
               with RDBGDM1.DBGDataSingle.DataSource , TSQLQuery ( DataSet ) do
                  try
                     DSsav := OnStateChange ;
                     OnStateChange := nil ;
                     if 1 < length ( InsertSQL.Text ) then
                        begin
                           Close ;
                           InsertSQL.Text := '*' ; // todo добавить выдачу SQL ошибки, если вызвали неверно заполненный запрос
                           QInit ( DataSet ) ;
                        end
                     else
                        if 1 < length ( UpdateSQL.Text ) then
                           begin
                              Close ;
                              UpdateSQL.Text := '*' ; // todo добавить выдачу SQL ошибки, если вызвали неверно заполненный запрос
                              QInit ( DataSet ) ;
                           end
                  finally
                     OnStateChange := DSsav ;
                  end ;
            end ;
         dsInsert :
            Filter := 'Method="I"' ;
         dsEdit :
            Filter := 'Method="U"' ;
      end ;
      Filtered := true ;
      if Active then First ; // неизвестно, как работает Filtered
      if not EOF then ItemIndex := 1 ; // todo проверить, что EOF верно отобразит наличие записей
   end ;

   ***tab stop в гриде при редактировании, без редактирования только стрелки

end;

procedure TRDataGrid.DBLCBActionsSingleSelect(Sender: TObject);
begin

//   ***после включения действия дизаблить контрол и отображать в нем выбранное действие, в т.ч. IUD
//   когда проставлять SQLInsert?

   ShowMessage(inttostr(DBLCBActionsSingle.ListSource.DataSet.RecordCount));

   DBLCBActionsSingle.ListSource.DataSet.RecNo:=DBLCBActionsSingle.ItemIndex;

   ShowMessage(DBLCBActionsSingle.ListSource.DataSet.FieldByName('ObjectName').AsString);
//   ShowMessage(inttostr(DBLCBActionsSingle.ItemIndex));

//   DBLCBActionsSingle.ItemIndex:=DBLCBActionsSingle.ItemIndex+1;
end;

procedure TRDataGrid.SQLQFilterAfterEdit(DataSet: TDataSet);
var Ig : TID ;
    Desc : string = '' ;
begin // редактирование в отдельной форме, здесь только для визуализации
   Ig := null ;
   if GetObject ( TFFilterSingle , nil , FrameDBGTree1.SQLQ.FieldByName ( 'ObjectName' ).AsString{todo по смыслу поле ObjectName<>параметру Alias} , nil , nil , Ig , Desc , nil , true ) then
      QInit ( FrameDBGTree1.SQLQ )
   else
      FrameDBGTree1.SQLQ.Cancel ;
end;

procedure TRDataGrid.BBActionClick(Sender: TObject);
begin
   // если действие A, то создать отдельную форму
end ;

procedure TRDataGrid.SQLQMainBeforePost(DataSet: TDataSet);
var i : integer ;
    PR : TParams ;
begin
   PR := TParams ( GetObjectProp ( DataSet , 'Params' , TParams ) ) ;

   for i := 0 to PR.Count - 1 do
      with DM1.QAttributesAll do
         if Locate ( 'Class;Attribute' , VarArrayOf ( [GetQueryInfo ( RDBGDM1.DBGDataSingle ){%H-}.Cls , PR{%H-}[i].Name] ) , [loCaseInsensitive] ) then
            PR[i].Value := DataSet.FieldByName ( FieldByName ( 'ColumnName' ).AsString ).Value ;
end ;

procedure TRDataGrid.Init ( GridObject : string ; IsSelectable : boolean ) ;
begin
   // todo сделать выбор фильтра по умолчанию и скрывать фильтры, если их только один

   RDBN.IsSelectable := IsSelectable ; // как узнать главный DBN для формы?

   with FrameDBGTree1.SQLQ do
   begin
//      SQL.Text := DM1.QClasses.SQL.Text ;
      ParamByName ( 'DB'    ).AsString := DM1.SQLConnector.DatabaseName ;
      ParamByName ( 'Class' ).AsString := GridObject ;
      QInit ( FrameDBGTree1.SQLQ ) ;
   end;

   Refresh ;

   InitQuickFilterNew ( RDBGDM1.DBGDataSingle , true ,true ) ;
end ;

procedure TRDataGrid.Refresh ;
begin
   RDBGDM1.DBGDataSingle.RefreshMasterDetail ( nil ) ;
end ;

procedure TRDataGrid.ToggleError ( C : TColor ) ;
begin
   SErrorSingle.Visible := ( C <> clNone ) ;
   PErrorSingle.Visible := ( C <> clNone ) ;

   if C <> clNone then
   begin
      SErrorSingle.Color := C ;
      PErrorSingle.Color := C ;
   end;
end;

end.
