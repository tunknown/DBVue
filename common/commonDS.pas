unit commonDS ;
// database related

interface

uses
   Classes , DB , dbgrids , grids ,
   {$IFNDEF FPC}MSAccess , ADODB{$ELSE}sqldb{$ENDIF} ;

type
//   TMSQuery = TADOQuery ;

   TMustEllipsis = ( meNone , meDateTime , meString , meObject , meDropDown ) ;
   TCustomGridHack = class ( TCustomGrid ) ; // FreePascal "-CR" (verify method calls) compiler option must be off even in DEBUG mode
   TCustomDBGridHack = class ( TCustomDBGrid ) ; // disable project option\debugging\Verify method calls (-CR)

   TDataSourceHack = class ( TDataSource )
      property DataLinks ;
   end ;

function LocateByParams(DS_in: TDataSet; Params_in: TParams): Boolean;
function CreateParamsListByStrings( SL: TStrings ): TParams;
function CreateParamsOnString ( FieldNames : string ) : TParams ;


procedure FieldsToParams ( DS : TDataSet ; PK_values : TParams ) ; // заполнение TParams значениями полей записи из TDataSet
function GetGridColumnByField ( DBG : TDBGrid ; Field : TField ) : TColumn ;
function GetColumnByName ( DBG : TDBGrid ; FName : string ) : TColumn ;
{$IFNDEF FPC}function GetActiveControlDataSet : TDataSet ;{$ENDIF}
function MustEllipsis ( f : TField ) : TMustEllipsis ;
procedure SetFieldsToColumns ( DBG : TDBGrid ) ; deprecated ;
function GetParamNames ( Params : TParams ) : string ;

function GetDataSourceGrid ( Cmp : TComponent ; DS : TDataSource ) : TCustomDBGrid ; overload ;
function GetDataSourceGrid ( Cmp : TComponent ; DS : TDataSource ; Field : TField ) : TCustomDBGrid ; overload ;
function GetDataSetGrid ( Cmp : TComponent ; DS : TDataSet ) : TCustomDBGrid ;
//procedure GetDataSourceDetail ( Cmp : TComponent ; DSO : TDataSource ; DataSetList : TList ) ;

{$IFNDEF FPC}procedure ParamsClear ( Parameters : TParameters  ) ; overload ;{$ENDIF}
procedure ParamsClear ( Params : TParams  ) ; overload ;
{$IFNDEF FPC}procedure ParamsClear ( Q      : TMSQuery ) ; overload ;{$ENDIF}

function QInit ( D   : TDataSet    ) : boolean ; overload ;
function QInit ( DS  : TDataSource ) : boolean ; overload ;
function QInit ( DBG : TDBGrid     ) : boolean ; overload ;

function GetIntFieldData ( F : TField ) : integer ; {$IF Declared(CompilerVersion) and (CompilerVersion >= 18.0)}inline ;{$IFEND}

function VarIsFilled ( v : variant ) : boolean ;
procedure ColumnizeGrid ( DBG : TDBGrid ) ;

implementation

uses
   Variants , typinfo , sysutils , forms , dialogs , controls
   , commonCTRL
   , uDM{вынести} ;

function VarIsFilled ( v : variant ) : boolean ;
begin
   Result := not VarIsNull ( v ) and not VarIsEmpty ( v ) ;
end;

{$IFNDEF FPC}procedure ParamsClear ( Parameters : TParameters  ) ; overload ;
var i : integer ;
begin
   with Parameters do
      for i := 0 to Count - 1 do
         Items[i].Value := VarNull ;
end ;{$ENDIF}

procedure ParamsClear ( Params : TParams ) ;
var i : integer ;
begin
   with Params do
      for i := 0 to Count - 1 do
         Items[i].Clear ;
end ;

{$IFNDEF FPC}procedure ParamsClear ( Q : TMSQuery ) ;
begin
   ParamsClear ( Q.Params ) ;
end ;{$ENDIF}

function LocateByParams ( DS_in : TDataSet ; Params_in : TParams ) : Boolean ;
var
   i : integer ;
   CurParam : TParam ;
   fields : string ;
   values : Variant ;
begin
   Result := false ;
   if not assigned ( Params_in ) then Exit ;

   fields := '' ;
   if Params_in.Count = 1 then i := 1 else i := Params_in.Count - 1 ; // на один элемент больше из-за того, что vararray из одного элемента не работает в Locate
   values := VarArrayCreate ( [0 , i] , varVariant ) ;

   try
      for i := 0 to Params_in.Count - 1 do
      begin
         CurParam := Params_in[i] ;
         if not assigned ( DS_in.FindField ( CurParam.Name ) ) then Exit ;

         fields := fields + CurParam.Name + ';' ;
         if VarIsNull ( CurParam.Value ) or VarIsEmpty ( CurParam.Value ) then values[i] := Null else values[i] := CurParam.Value ;
      end ;

      if Params_in.Count = 1 then // на один элемент больше из-за того, что vararray из одного элемента не работает в Locate
      begin
         fields := fields + Params_in[0].Name ;
         values[Params_in.Count] := values[0] ;
      end
      else
         SetLength ( fields , Length ( fields ) - 1 ) ;

      Result := DS_In.Locate ( fields , values , [loCaseInsensitive] ) ;
   finally
      Finalize ( values ) ;
   end ;
end ;

function CreateParamsListByStrings ( SL : TStrings ) : TParams ;
var i : Integer ;
begin
   Result := nil ;
   if not assigned ( SL ) then Exit ;

   try
      Result := TParams.Create ;
      for i := 0 to SL.Count - 1 do
         Result.CreateParam ( ftUnknown , SL[i] , ptUnknown ) ;
   except
      if Assigned ( Result ) then Result.Free ;
      raise ;
   end ;
end ;

function CreateParamsOnString ( FieldNames : string ) : TParams ;
var Pos : Integer ;
begin
   Result := nil ;
   if FieldNames = '' then Exit ;

   Result := TParams.Create ;
   try
      Pos := 1 ;
      while Pos <= Length ( FieldNames ) do
         Result.CreateParam ( ftUnknown , ExtractFieldName ( FieldNames , Pos ) , ptUnknown ) ;
   except
      if Assigned ( Result ) then Result.Free ;
      raise ;
   end ;
end ;

procedure FieldsToParams ( DS : TDataSet ; PK_values : TParams ) ;
var i : Integer ;
    CurField : TField ;
begin
   if Assigned ( DS ) then
      for i := 0 to PK_values.Count - 1 do
      begin
         CurField := DS.FieldByName ( PK_values[i].Name ) ;
         PK_values[i].DataType := CurField.DataType ;
         if CurField.IsNull then
            PK_values[i].Clear
         else
            if CurField is TDateTimeField then
               PK_values[i].AsDateTime := TDateTimeField ( CurField ).AsDateTime
            else
               PK_values[i].Value := CurField.Value ;
      end
   else
      for i := 0 to PK_values.Count - 1 do
         PK_values[i].Clear ;
end ;

function GetParamNames ( Params : TParams ) : string ;
var i : Integer ;
begin
   Result := '' ;
   for i := 0 to Params.Count - 1 do
      Result := Result + Params[i].Name + ';' ;

   if Result <> '' then SetLength ( Result , Length ( Result ) - 1 ) ;
end ;

function GetGridColumnByField ( DBG : TDBGrid ; Field : TField ) : TColumn ;
var i : integer ;
begin
   if assigned ( Field ) then
      for i := 0 to DBG.Columns.Count - 1 do
         if DBG.Columns[i].Field = Field then
         begin
            Result := DBG.Columns[i] ;
            Exit ;
         end ;
   Result := nil ;
end ;

function GetColumnByName ( DBG : TDBGrid ; FName : string ) : TColumn ;
var i : integer ;
begin
   for i := 0 to DBG.Columns.Count - 1 do
   begin
      Result := DBG.Columns[i] ;
      if Result.FieldName = FName then Exit ;
   end ;
   Result := nil ;
end ;

{$IFNDEF FPC}function GetActiveControlDataSet : TDataSet ;
var O : TObject ; // TCustomDBGrid , TDBLookupControl
begin
   O := GetObjectProperty ( Screen.ActiveControl , 'ListSource' ) ;
   if not assigned ( O ) then O := GetObjectProperty ( Screen.ActiveControl , 'DataSource' ) ;
   if O is TDataSource then
      Result := TDataSource ( O ).DataSet
   else
      Result := nil ;
end ;{$ENDIF}

function MustEllipsis ( f : TField ) : TMustEllipsis ;
begin
   Result := meNone ;

   if not assigned ( f ) then Exit ;

   if f.FieldKind = fkLookup then
      Result := meDropDown
   else
      if f.LookupCache then
         Result := meObject
      else
         if f.DataType in [ftDateTime , ftDate , ftTime] then
            Result := meDateTime
         else
            if    ( f.DataType in [ftString , ftWideString] ) and ( f.Size >= 64 )
               or ( f.DataType in [ftMemo , ftFmtMemo] )
               then
//               and ( f.FieldName <> 'Caption' )
//               and (    ( RightStr ( f.FieldName , 4 ) <> 'Name' )
//                     or not assigned ( f.DataSet.FindField ( LeftStr ( f.FieldName , Length ( f.FieldName ) - 4 ) ) ) ) then // попытка не вызывать окно для полей типа ContragentName+Contragent
               Result := meString ;
end ;

procedure SetFieldsToColumns ( DBG : TDBGrid ) ; deprecated{можно вызывать из QInit или из TDBGrid.OnColEnter} ;
var i : integer ;
begin // можно вызывать из QInit или из TDBGrid.OnColEnter


// в SetFieldsToColumns тоже нужно OnDataChange стирать

   if not assigned ( DBG ) then Exit ;

   DBG.DataSource.DataSet.DisableControls ; // Чтобы не срабатывал TDataSource.OnDataChange на изменение свойств поля
   try
      with DBG.Columns do
         for i := 0 to Count - 1 do
            with Items[i] do
               if not assigned ( Field ) then // если у колонки нет поля, не обрабатываем designtime колонки под которыми ещё не появились поля
                  Exit
               else
               begin
                  case MustEllipsis ( Field ) of
                     meNone :
                        if ButtonStyle <> cbsEllipsis then ButtonStyle := cbsNone ; // если колонки уже созданы в гриде
                     meDropDown :
                        ButtonStyle := cbsAuto ;
                     else
                        ButtonStyle := cbsEllipsis ;
                  end ;
//                  DropDownRows := 10 ; // не работает, т.к. потом заменяется умолчанием =7

                  if Field.DisplayWidth = Field.Size then
                     case Field.DataType of
                        ftString ,
                        ftFixedChar ,
                        ftWideString :
                           begin
                              if Field.Size < 16 then
                                 Field.DisplayWidth := trunc ( Field.Size * 0.75 )
                              else
                                 Field.DisplayWidth := trunc ( Field.Size * 0.15 ) ;
                           end ;

                        {ftSmallint ,
                        ftInteger ,
                        ftWord ,
                        ftLargeint :
                           }

                        {ftFloat ,
                        ftCurrency :
                           }

                        {ftBoolean :
                           }

                        ftDate ,
                        ftTime ,
                        ftDateTime :
                           Field.DisplayWidth := 11 ;

                        {ftBytes ,
                        ftVarBytes ,
                        ftBlob ,
                        ftMemo :
                           }

                        ftGuid :
                           begin
                              //Title.Font.Size := 6 ; // не работает
                              Field.DisplayWidth := 5 ;
                              Field.Alignment := taRightJustify ;
                           end ;

                        {ftVariant :
                           }
                     end ;

                  if Width > {%H-}TCustomGridHack ( DBG ).GridWidth then Width := trunc ( {%H-}TCustomGridHack ( DBG ).GridWidth * 0.95 ) ;
               end ;
   finally
      DBG.DataSource.DataSet.EnableControls ;
   end;
end;

function GetDataSourceGrid ( Cmp : TComponent ; DS : TDataSource ) : TCustomDBGrid ;
var i : integer ;
{$IFDEF FPC}
    CurCmp : TComponent ;
{$ENDIF}
begin
{$IFNDEF FPC}
   for i := 0 to TDataSourceHack ( DS ).DataLinks.Count - 1 do
      if TObject ( TDataSourceHack ( DS ).DataLinks[i] ) is TGridDataLink then
      begin
         Result := TGridDataLink ( TDataSourceHack ( DS ).DataLinks[i] ).Grid ;
         if Result.CanFocus then exit ; // ищет первый грид, который виден на экране. На случай, когда на один запрос смотрят два грида на разных закладках
      end ;
   Result := nil ;
{$ELSE}
   if not assigned ( Cmp ) then Cmp := Screen{Application} ;

   for i := 0 to Cmp.ComponentCount - 1 do
   begin
      CurCmp := Cmp.Components[i] ;
      if CurCmp is TCustomDBGrid then
      begin
         Result := TCustomDBGrid ( CurCmp ) ;
         if Result.DataSource <> DS then Result := nil ;
      end
      else
         Result := GetDataSourceGrid ( CurCmp , DS ) ;

      if assigned ( Result ) then Exit ;
   end ;
   Result := nil ;
{$ENDIF}
end ;

function GetDataSourceGrid ( Cmp : TComponent ; DS : TDataSource ; Field : TField ) : TCustomDBGrid ;
var i , j : integer ;
{$IFDEF FPC}
    CurCmp : TComponent ;
{$ENDIF}
begin // найдёт первый подходящий грид на датасет по полю или последний грид, если такого поля нет ни в одном
{$IFNDEF FPC}
   for i := 0 to TDataSourceHack ( DS ).DataLinks.Count - 1 do
      if TObject ( TDataSourceHack ( DS ).DataLinks[i] ) is TGridDataLink then
      begin
         Result := TGridDataLink ( TDataSourceHack ( DS ).DataLinks[i] ).Grid ;

         if Result.Focused or ( assigned ( TCustomGridHack ( Result ).InplaceEditor ) and TCustomGridHack ( Result ).InplaceEditor.Focused ) then Exit ;

         for j := 0 to TCustomDBGridHack ( Result ).Columns.Count - 1 do
            if ( TCustomDBGridHack ( Result ).Columns[j].Field = Field ) and Result.CanFocus then Exit ; // ищет первый грид, который виден на экране. На случай, когда на один запрос смотрят два грида на разных закладках
      end ;
   Result := nil ;
{$ELSE}
   if not assigned ( Cmp ) then Cmp := Screen{Application} ;

   for i := 0 to Cmp.ComponentCount - 1 do
   begin
      CurCmp := Cmp.Components[i] ;
      if CurCmp is TCustomDBGrid then
      begin
         Result := TCustomDBGrid ( CurCmp ) ;
         if Result.DataSource <> DS then Result := nil ;


         if not Result.Focused and not ( assigned ( {%H-}TCustomGridHack ( Result ).InplaceEditor ) and {%H-}TCustomGridHack ( Result ).InplaceEditor.Focused ) then Result := nil ;

         for j := 0 to TCustomDBGridHack ( Result ).Columns.Count - 1 do
            if ( TCustomDBGridHack ( Result ).Columns[j].Field <> Field ) or not Result.CanFocus then Result := nil ; // ищет первый грид, который виден на экране. На случай, когда на один запрос смотрят два грида на разных закладках
      end
      else
         Result := GetDataSourceGrid ( CurCmp , DS , Field ) ;

      if assigned ( Result ) then Exit ;
   end ;
   Result := nil ;
{$ENDIF}
end ;

function GetDataSetGrid ( Cmp : TComponent ; DS : TDataSet ) : TCustomDBGrid ;
var j : integer ;

   procedure CompoCycle ( Cmp : TComponent ) ;
   var i : integer ;
       CurCmp : TComponent ;
   begin
      for i := 0 to Cmp.ComponentCount - 1 do
      begin
         CurCmp := Cmp.Components[i] ;
         if CurCmp is TDBGrid then
         begin
            Result := TCustomDBGrid ( CurCmp ) ;
            if not assigned ( Result.DataSource ) or ( Result.DataSource.DataSet <> DS ) then Result := nil ;
         end
         else
            Result := GetDataSetGrid ( CurCmp , DS ) ;

         if assigned ( Result ) then Exit ;
      end ;
   end ;

begin
   Result := nil ;
   if assigned ( Cmp ) then
   begin
      CompoCycle ( Cmp ) ;
      if assigned ( Result ) then Exit ;
   end
   else
      for j := 0 to Screen.FormCount - 1 do
      begin
         CompoCycle ( Screen.Forms[j] ) ;
         if assigned ( Result ) then Exit ;
      end ;
end ;

{procedure GetDataSourceDetail ( Cmp : TComponent ; DSO : TDataSource ; DataSetList : TList ) ;
var j : integer ;

   procedure CompoCycle ( Cmp : TComponent ) ;
   var i : integer ;
       CurCmp : TComponent ;
   begin
      for i := 0 to Cmp.ComponentCount - 1 do
      begin
         CurCmp := Cmp.Components[i] ;
         if CurCmp.InheritsFrom ( TDataSet ) then
         begin
            if TDataSet ( CurCmp ).DataSource = DSO then DataSetList.Add ( CurCmp ) ;
         end
         else
            GetDataSourceDetail ( CurCmp , DSO , DataSetList ) ;
      end ;
   end ;

begin
   if assigned ( Cmp ) then
      CompoCycle ( Cmp )
   else
      for j := 0 to Screen.FormCount - 1 do
         CompoCycle ( Screen.Forms[j] ) ;
end ;}

function QInitEx ( C : TComponent ) : boolean ;
var PKValue : integer ;
    Locating : boolean ;
    Located : boolean = false ;
    D : TDataSet ;
    DS : TDataSource ;
    DBG : TDBGrid ;
    Key: Word = 0 ;
begin
   D   := nil ;
   DS  := nil ;
   DBG := nil ;

   if C is TDataSet then
      D := TDataSet ( C )
   else
      if C is TDataSource then
      begin
         DS := TDataSource ( C ) ;
         D  := DS.DataSet ;
      end
      else
         if C is TDBGrid then
         begin
            DBG := TDBGrid ( C ) ;
            DS  := DBG.DataSource ;
            if assigned ( DS ) then D := DS.DataSet ;
         end ;

   Assert ( assigned ( D ) , '[QInitEx]неподдерживаемый параметр' ) ; // nil доберётся сюда, т.к. nil не опознается никаким классом

   with D do
   begin
      Locating := Active and assigned ( FindField ( 'Id' ) ) and ( RecordCount <> 0 ) ;
      if Locating then PKValue := FieldByName ( 'Id' ).AsInteger else PKValue := 0 ;
      DisableControls ;
      try
         Active := false ;
         Active := true ;
         Last ; // FetchAll правильнее; todo в параметры процедуры
         First ;
      finally
         Result := not IsEmpty ; // RecordCount не для всех компонентов работает
         if Locating then Located := Locate ( 'Id' , PKValue {%H-}, [] ) ;

         if not assigned ( DBG ) then
            if assigned ( DS ) then
               DBG := TDBGrid ( GetDataSourceGrid ( nil , DS ) )
            else
               DBG := TDBGrid ( GetDataSetGrid ( nil , D ) ) ;

         EnableControls ;


// в SetFieldsToColumns тоже нужно OnDataChange стирать
         SetFieldsToColumns ( DBG ) ; // колонки появятся только после EnableControls
         if assigned ( DBG ) and ( pos ( '|' , D.Fields[0].FieldName ) <> 0 ) then ColumnizeGrid ( DBG ) ; // todo вынести? переделать DBG->DataSet
      end ;

      if not Located and assigned ( AfterScroll ) then AfterScroll ( D ) ; // пусть AfterScroll срабатывает и при 0 записей, чтобы обновить и детейлы в случае пустого мастера
      if not assigned ( AfterScroll ) and assigned ( DBG ) then
      begin
         if assigned ( DBG.OnKeyDown ) then
            DBG.OnKeyDown ( DBG , Key , [] )
         else
            if assigned ( DBG.OnMouseDown ) then
               DBG.OnMouseDown ( DBG , mbExtra2 , [] , -1 , -1 ) ;
      end ;
   end ;
end ;

function QInit ( D : TDataSet ) : boolean ;
begin
   Result := QInitEx ( D ) ;
end ;

function QInit ( DS : TDataSource ) : boolean ;
begin
   Result := QInitEx ( DS ) ;
end ;

function QInit ( DBG : TDBGrid ) : boolean ;
begin
   DBG.SelectedRows.Clear ; // костыль обходит ошибку DBGridsMy.TDBGrid.DoMasterDetail->TBookmarkList.GetCurrentRowSelected->TBookmarkList.IndexOf->TBookmarkList.Find->TBookmarkList.Find->TCustomBufDataset.CompareBookmarks->ARecord2 := ARecord2[IndNr].prior;
   Result := QInitEx ( DBG ) ;
end ;

function GetIntFieldData ( F : TField ) : integer ; {$IF Declared(CompilerVersion) and (CompilerVersion >= 18.0)}inline ;{$IFEND}
begin // для несущественного ускорения
//   Result := F.AsInteger ;

   Result := 0 ;
   F.DataSet.GetFieldData ( F , @Result ) ; // если идёт только сравнение с ним, то не важен размер буфера (Result) int/smallint/tinyint?
end ;

procedure ColumnizeGrid ( DBG : TDBGrid ) ;
var s , GridClass , sClassRef , sAttributeRef , sCaption , sWidth , sMethod , sMask : string ;
    w , i , j : integer ;
    Type1 : char = #0 ;
    F : TField ;
    C : TColumn ;
    CC : TDBGridColumns ;
    DBGM : TDBGrid ;
    DSMaster : TDataSet ;

   function FindDBGrid ( Root : TComponent ; const CName : string ) : TComponent ;
   var i : integer ;
   begin // искать среди всех фреймов формы, полагая, что они создаются в порядке, согласном master-detail
      if CName <> '' then
         for i := 0 to Root.ComponentCount - 1 do
         begin
            Result := Root.Components[i] ;
            if ( Result is TDBGrid ) and ( CompareText ( GetQueryInfo ( TDBGrid ( Result ) ).Cls , CName ) = 0 ) then
               exit
            else
            begin
               Result := FindDBGrid ( Result , CName ) ;
               if assigned ( Result ) then exit ;
            end ;
         end ;
      Result := nil ;
   end ;

begin
   GridClass := GetQueryInfo ( DBG ).Cls ;

   CC := DBG.Columns ;

   DBG.DataSource.DataSet.DisableControls ; // не помогает, чтобы горизонтальный скролбар грида не отражал оперативно изменение ширины полей
   try
      for i := 0 to CC.Count - 1 do
      begin
         C := CC.Items[i] ;
         F := C.Field ;
         F.Required := false ; // пусть только сервер БД определяет

         if DM1.QAttributesAll.Locate ( 'Class;ColumnName' , VarArrayOf ( [GridClass , F.FieldName] ) , [loCaseInsensitive] ) then
         begin // обрабатываем только поля с разделителями в названии
            with DM1.QAttributesAll do
            begin
               sClassRef     := FieldByName ( 'ClassRef' ).AsString ;
               sAttributeRef := Trim ( FieldByName ( 'AttributeRef' ).AsString ) ; // todo убрать trim
               sCaption      := FieldByName ( 'Caption' ).AsString ;
               sWidth        := Trim ( FieldByName ( 'Width' ).AsString ) ; // todo убрать trim
               sMethod       := FieldByName ( 'Method' ).AsString ;
               sMask         := FieldByName ( 'Mask' ).AsString ;
            end ;

            if sClassRef <> '' then
            begin
               DBGM := TDBGrid ( FindDBGrid ( GetParentRoot ( DBG , TForm ) , sClassRef ) ) ;
               if assigned ( DBGM ) then
               begin
                  DSMaster := DBGM.DataSource.DataSet ;
                  {for j := 0 to DSMaster.FieldCount - 1 do
                     with DSMaster.Fields[j] do
                        if KeyFields = '' then // уже сделано при инициализации формы, а при multiselect там уже лежит список идентификаторов для фильтрации detail по нему
                           if     QAttributesAll.Locate ( 'Class;ColumnName' , VarArrayOf ( [sClassRef , FieldName] ) , [loCaseInsensitive] )
                              and ( Trim ( QAttributesAll.FieldByName ( 'Attribute' ).AsString ) = sAttributeRef ) then
                                 KeyFields := ' ' ;} // проставляет признак полю чужого датасета, при его QInit при фильтрации признак сбрасывается
                  F.LookupDataSet := DSMaster ; // в KeyFields полей мастера лежат значения для обязательной фильтрации себя
               end ;
            end ;

            F.Visible := ( sCaption <> '' ) ;
            if F.Visible then
            begin
               F.DisplayLabel := '    ' + sCaption ; // todo добавлять пробелы только для поля с наложенным фильтром
               F.EditMask     := sMask ;
               if TryStrToInt ( sWidth , w ) then
                  F.DisplayWidth := w
               else
                  if 0 < Pos ( sWidth , '%' ) then ; // ***сделать относительную ширину колонок

               if sMethod <> '' then Type1 := sMethod[1] ; // [1] от пустой строки даёт ошибку

               if Type1 in ['F' , 'J'] then
               begin
                  C.ButtonStyle := cbsEllipsis ;
                  //DBG.OnEditButtonClick := @DM1.DBGEditButtonClick ;
                  //FieldByName ( 'ClassRef' ).AsString ;
                  //FieldByName ( 'AttributeRef' ).AsString ;
               end
               else
                  C.ButtonStyle := cbsAuto ; // кажется, отличается от поведения Delphi, где при cbsNone в ячейке создаётся Editor
            end ;
         end ;
      end ;
   finally
      DBG.DataSource.DataSet.EnableControls ;
   end ;
end;

end.
