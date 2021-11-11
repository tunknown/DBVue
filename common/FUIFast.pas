unit FUIFast ;
// юнит uDBLEdit должен быть уже открыт, иначе ошибка

interface

uses
   Windows, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ExtCtrls, db, DBGrids, ComCtrls, DBCtrls, Buttons, grids ,
   commonDS, DBGridsMy{строго после DBGrids} ;

type

   { TSQLFilterUIFast }
   TCustomGridHack = class ( TCustomGrid ) ; // FreePascal "-CR" (verify method calls) compiler option must be off even in DEBUG mode

   TFilterOrderEnum = ( IsFilter , IsOrder ) ;
   TIsFilterOrder = set of TFilterOrderEnum ;

   TSQLFilterUIFast = class(TForm)
      DSValues: TDataSource;
      PComparison: TPanel;
      LBComparison: TListBox;
      DBLEValue: TDBLookupComboBox;
      BBSearch: TBitBtn;
      RGOrder: TRadioGroup;
      CBVisible: TCheckBox;
      BBSet: TBitBtn;
      BBClear: TBitBtn;

      procedure FormCreate                  ( Sender : TObject ) ;
      procedure FormShow                    ( Sender : TObject ) ;
      procedure FormDeactivate              ( Sender : TObject ) ;
      procedure FormDestroy                 ( Sender : TObject ) ;
      procedure FormKeyDown                 ( Sender : TObject ; var Key : Word ; Shift : TShiftState ) ;

      procedure BBSetClick                  ( Sender : TObject ) ;
      procedure BBClearClick                ( Sender : TObject ) ;

      procedure FilterControlEnter          ( Sender : TObject ) ;
      procedure FilterChange                ( Sender : TObject ) ;
      procedure LBComparisonSelectionChange ( Sender : TObject ; User : boolean ) ;

      procedure DrawColumnTitle ( Sender : TObject ; const Rect : TRect ; {%H-}DataCol : Integer ; Column : TColumn ; {%H-}State : TGridDrawState ) ;
      procedure MouseLeave      ( Sender : TObject ) ;
      procedure MouseMove       ( Sender : TObject ; {%H-}Shift : TShiftState ; X , Y : Integer ) ;

      procedure DrawFilterOrder ( DBG : TDBGrid ; const Rect : TRect ; Column : TColumn ; State : TGridDrawState ; bFilter : boolean ; sOrderBy : string ) ;
   private
      DBG : TDBGrid ;
      FOnField : TField ;
      Searches : array of Variant ;
      SearchIndex : integer ;

      FFilterValueModified ,
      FPopupProcessed{был правый клик по гриду и отработал Popup, не надо показывать окно} ,
      FSmartFilterSign : boolean ;

      FProcSaveTitleClick : TDBGridClickEvent ;
      FProcSavePopup : TNotifyEvent ;

      function  GetFilterValueModified : boolean ;
   public
      //SQLFilter{просто указатель!} : TDSQLFlt ;
      procedure BBSearchClick       ( Sender : TObject ) ;

      function  GetOnFieldName      : string ;
      function  GetFilterValue      : string ;
      procedure SetFilterValue      ( Value : string ) ;
      procedure ApplyFilterControls ( FieldName , Value : string ; Searched : boolean ) ;
      procedure Enfilter            ( FieldName , Value : string ; finish : boolean ) ;
      procedure ClearFilterVisual   ( Refresh1 : boolean ) ;
      procedure DBGTitleClick       ( Column : TColumn ) ;
      procedure OnPopupEvent        ( Sender : TObject ) ;

      property  OnFieldName         : string  read GetOnFieldName ;
      property  FilterValueModified : boolean read GetFilterValueModified write FFilterValueModified ;
   end ;

function InitQuickFilterNew ( DBG : TDBGrid ; WithList , SmartFilter : boolean ) : TSQLFilterUIFast ;
function IsForFilterOrder ( const X : integer ; const R : TRect ) : TIsFilterOrder ;

var SQLFilterUIFast : TSQLFilterUIFast = nil ; // одновременно может быть видим только один быстрый фильтр

implementation

uses
   Variants , SQLDB , Graphics
   , uDM ;

{$R *.LFM}

////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TSQLFilterUIFast.FormCreate(Sender: TObject);
begin
   LBComparison.Items.AddDelimitedText ( '|' + cCompare , '|' , true ) ;
end ;

procedure TSQLFilterUIFast.FormShow(Sender: TObject);
begin
   if not BBSet.Focused then BBSet.SetFocus ; // возвращаем фокус после нажатия в прошлый вызов окна кнопки отмены
end ;

procedure TSQLFilterUIFast.FormDeactivate(Sender: TObject);
begin
   Hide ; // если сюда попадёт из FormShow, будет ошибка
   SetLength ( Searches , 0 ) ;
end ;

procedure TSQLFilterUIFast.FormDestroy(Sender: TObject);
begin
   ClearFilterVisual ( false ) ;

//   SQLFilter.DBGrid.OnTitleClick := FProcSaveTitleClick ;
//   if assigned ( FProcSavePopup ) then SQLFilter.DBGrid.PopupMenu.OnPopup := FProcSavePopup ;
end;

procedure TSQLFilterUIFast.FormKeyDown(Sender: TObject; var Key: Word;Shift: TShiftState);
begin
   if key = VK_ESCAPE then Hide ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
function TSQLFilterUIFast.GetFilterValue : string ;
begin
{   if EParam.Visible then
      Result := EParam.Text
   else
      if CBList.Visible then
         Result := CBList.Text
      else
         if DTPParam.Checked then
            Result := DateTimeToStr ( DTPParam.DateTime )
         else
            Result := '' ;}
end ;

procedure TSQLFilterUIFast.SetFilterValue ( Value : string ) ;
var temp : integer ;
begin
{   if EParam.Visible then
      EParam.Text := Value
   else
      if CBList.Visible then
         CBList.Text := Value
      else
      begin
         DTPParam.Checked := ( Value <> '' ) ;
         temp := Pos ( ' ' , Value ) ;
         if temp = 0 then temp := length ( Value ) ;
         if DTPParam.Checked then
            DTPParam.DateTime := StrToDate ( copy ( Value , 1 , temp ) )
         else
            DTPParam.DateTime := now ;
      end ;}
end ;

function TSQLFilterUIFast.GetOnFieldName : string ;
begin
   if assigned ( FOnField ) then Result := FOnField.FieldName else Result := '' ;
end ;

procedure TSQLFilterUIFast.FilterControlEnter(Sender: TObject);
begin
{   Eparam.Text := '' ;
   CBList.Text := '' ;}
end;

procedure TSQLFilterUIFast.ApplyFilterControls ( FieldName , Value : string ; Searched : boolean ) ;
var check_here : boolean ;
begin
{   if CBCompare.Items.IndexOf ( Trim ( CBCompare.Text ) ) = -1 then CBCompare.ItemIndex := 0 ;
   if CBSort.Items.IndexOf    ( Trim ( CBSort.Text    ) ) = -1 then CBSort.ItemIndex    := 0 ;

   if ( Trim ( CBCompare.Text ) <> '' ) and ( Trim ( Value ) =  '' ) then CBCompare.ItemIndex := 0 ;
   if ( Trim ( CBCompare.Text ) =  '' ) and ( Trim ( Value ) <> '' ) then CBCompare.ItemIndex := CBCompare.Items.IndexOf ( 'равно' ) ;

   SQLFilter.ApplyFilter ( CBCompare.ItemIndex , CBSort.ItemIndex , FieldName , Value , Searched ) ;}
end;

procedure TSQLFilterUIFast.Enfilter ( FieldName , Value : string ; finish : boolean ) ;
var check_here : boolean ;
begin
{   if finish then
      ApplyFilterControls ( FieldName , Value , false )
   else
      SQLFilter.PrepareFilter ( 0 , 0 , FieldName , Value ) ;}
end ;

procedure TSQLFilterUIFast.ClearFilterVisual ( Refresh1 : boolean ) ;
var check_here : boolean ;
begin
{   FPopupProcessed := false ; // без этого следующий TitleClick не сработает, если снятие фильтра было без TitleClick

   SQLFilter.ClearFilterVisual ( Refresh ) ;}
end ;

function IsForFilterOrder ( const X : integer ; const R : TRect ) : TIsFilterOrder ;
// титлклик слева- фильтр по текущему/снятие фильтра, справа сортировка А-Я/Я-А/отключение, посередине окно минифильтра с подсветкой
begin
   Result := [] ;
   if X < R.Left  + R.Height + R.Height div 4 then Result := Result - [IsOrder]  else Result := Result + [IsOrder]  ;
   if X < R.Right - R.Height - R.Height div 4 then Result := Result + [IsFilter] else Result := Result - [IsFilter] ;
end ;

procedure TSQLFilterUIFast.DBGTitleClick ( Column : TColumn ) ;
var sOper : string = '' ;
    sParam : string = '' ;
    sOrder : string = '' ;
    bVisibility , bFilter : boolean ;
    i : integer ;
    iCol : integer = 0 ;
    iRow : integer = 0 ;
    ASelect : ASQLSelect = nil ;
    AWhere : ASQLWhere = nil ;
    AOrderBy : ASQLOrderBy = nil ;
    P , CP : TPoint ;
    R : TRect ;
    FO : TIsFilterOrder ;
begin
   if not assigned ( Column ) then Exit ;
   if FPopupProcessed then
   begin
      FPopupProcessed := false ;
      Exit ;
   end ;

   DBG := TDBGrid ( Column.Grid ) ;

   if assigned ( FProcSaveTitleClick ) then FProcSaveTitleClick ( TColumn ( Column ) ) ;

   SetLength ( ASelect  , 1 ) ;
   SetLength ( AWhere   , 1 ) ;
   SetLength ( AOrderBy , 1 ) ;
   try
      if not DM1.SQLParse ( TSQLQuery ( Column.Field.DataSet ).SQL , ASelect , ASQLFrom ( nil^ ) , AWhere , AOrderBy ) then Exit ;

      bVisibility := false ;
      for i := 0 to Length ( ASelect ) - 1 do
         if ASelect[i].FieldName = Column.FieldName then
         begin
            bVisibility := true ;
            break ;
         end ;
      CBVisible.Checked := bVisibility ;

      RGOrder.ItemIndex := 0 ;
      for i := 0 to Length ( AOrderBy ) - 1 do
         if AOrderBy[i].FieldName = Column.FieldName then
         begin
            sOrder := AOrderBy[i].Order ;
            if ( sOrder = cAsc ) or ( sOrder = ''{на всякий случай, т.к. не поддерживается} ) then
               RGOrder.ItemIndex := 1
            else
               if sOrder = cDesc then
                  RGOrder.ItemIndex := 2 ;
            break ;
         end ;

      with DBLEValue do
      begin
         ListSource.DataSet := DM1.GetCacheFilter ( Column.Field ) ; // при незаполненном DataSource выбор из списка работает, но в поле можно вручную менять текст
         KeyField  := DSValues.DataSet.Fields[0].FieldName ;
         ListField := KeyField ;
      end ;

      for i := 0 to Length ( AWhere ) - 1 do
         if ( AWhere[i].FieldName = Column.FieldName ) and ( AWhere[i].Comparison <> 'in' ){возможный MasterDetail пропускаем} then
         begin
            sOper  := AWhere[i].Comparison ;
            sParam := AWhere[i].Parameter ;
            break ;
         end ;

      if sOper = '' then // быстрая подстановка для удобства, чтобы только нажать одну кнопку
      begin
         with LBComparison do ItemIndex := Items.IndexOf ( '=' ) ;
         DBLEValue.Text := Column.Field.AsString ;
      end
      else
      begin
         i := LBComparison.Items.IndexOf ( sOper ) ;
         if i = -1 then i := 0 ; // если фильтра нет, других ошибок не должно быть, т.к. запрос формируем сами
         LBComparison.ItemIndex := i ;
         DBLEValue.Text := sParam ;
      end ;

      CP := Mouse.CursorPos ;
      with DBG do
      begin
         P := ScreenToClient ( CP ) ;
         MouseToCell ( P.X , P.Y , iCol , iRow ) ;
         R := CellRect ( iCol , iRow ) ;
      end ;

      FO := IsForFilterOrder ( P.X , R ) ;
      if FO = [IsFilter , IsOrder] then
      begin
         Left := CP.X ;
         Top  := CP.Y ;

         Caption := '[' + Trim ( Column.Title.Caption ) + ']' + sOper + sParam ;
         FOnField := Column.Field ;

         i := Width - DBLEValue.Width + Column.Width ;
         if Column.Grid.Width < i then Width := Column.Grid.Width else Width := i ; //FOnField.DisplayWidth * DBLEValue.Font.GetTextWidth ( 'W' ) ;

         Show ;

         if FSmartFilterSign and assigned ( Column ) then SetFilterValue ( FOnField.AsString ) ;
      end
      else
         if FO = [IsFilter] then
         begin
            bFilter := false ;
            DM1.GetFilterOrder ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , bFilter , sOrder ) ;
            if bFilter then
            begin
               sOper := '' ;
               sParam := '' ;
            end
            else
            begin
               sOper := '=' ;
               sParam := Column.Field.AsString ;
            end ;
            DM1.SQLSet ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , sOper , sParam , string ( nil^ ) , boolean ( nil^ ) ) ;
            QInit ( DBG ) ; // ColumnizeGrid работает только при обновлении DBG, а не DataSet
         end
         else
            if FO = [IsOrder] then
            begin
               DM1.GetFilterOrder ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , bFilter , sOrder ) ;
               if sOrder = '' then sOrder := cAsc else if sOrder = cAsc then sOrder := cDesc else sOrder := '' ;
               DM1.SQLSet ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , string ( nil^ ) , string ( nil^ ) , sOrder , boolean ( nil^ ) ) ;
               QInit ( DBG ) ; // ColumnizeGrid работает только при обновлении DBG, а не DataSet
            end ;
   finally
      if ASelect  <> nil then ASelect  := nil ;
      if AWhere   <> nil then AWhere   := nil ;
      if AOrderBy <> nil then AOrderBy := nil ;
   end;
end ;

procedure TSQLFilterUIFast.OnPopupEvent ( Sender : TObject ) ;
begin
   FPopupProcessed := true ; // чтобы после отработки OnPopup ещё и OnTitleClick не вызывался

   if assigned ( FProcSavePopup ) then FProcSavePopup ( Sender ) ;
end ;

procedure TSQLFilterUIFast.BBSetClick(Sender: TObject);
var DS : TSQLQuery ;
    s , compare , param : string ;
begin

//*** как установить сортировку не затрагивая фильтр?

   DS := TSQLQuery ( FOnField.DataSet ) ;

   case RGOrder.ItemIndex of
      0 : s := '' ;
      1 : s := cAsc ;
      2 : s := cDesc ;
   end ;

   compare := LBComparison.GetSelectedText ;
   param := DBLEValue.Text ;
   DM1.SQLSet ( DS.SQL , FOnField.FieldName , compare , param , s , boolean ( nil^ ) ) ;
   QInit ( DBG ) ; // ColumnizeGrid работает только при обновлении DBG, а не DataSet

   Hide ;
end ;

procedure TSQLFilterUIFast.BBClearClick(Sender: TObject);
var DS : TSQLQuery ;
    s , compare , param : string ;
begin
   DS := TSQLQuery ( FOnField.DataSet ) ;

   case RGOrder.ItemIndex of
      0 : s := '' ;
      1 : s := cAsc ;
      2 : s := cDesc ;
   end ;

   LBComparison.ItemIndex := -1 ;
   DBLEValue.Text := '' ;

   compare := LBComparison.GetSelectedText ;
   param := DBLEValue.Text ;
   DM1.SQLSet ( DS.SQL , FOnField.FieldName , compare , param , s , boolean ( nil^ ) ) ;
   QInit ( DBG ) ; // ColumnizeGrid работает только при обновлении DBG, а не DataSet

   Hide ;
end;

procedure TSQLFilterUIFast.BBSearchClick(Sender: TObject);
var i , ItemIndex : integer ;
    bmk : TBookmark ;
    ac : TDataSetNotifyEvent ;
    FieldValue : TField ;
 check_here : boolean ;
begin
{   if FilterValueModified then
   begin
      FilterValueModified := false ;
      SetLength ( Searches , 0 ) ;
   end ;

   with SQLFilter , DataSet do
   begin
      if length ( Searches ) = 0 then
      begin
         bmk := GetBookmark ;
         ac := AfterScroll ;
         ItemIndex := CBCompare.ItemIndex ;
         try
            AfterScroll := nil ;
            DisableControls ;
            ApplyFilterControls ( OnFieldName , GetFilterValue , true ) ;
            SetLength ( Searches , RecordCount ) ;

            FieldValue := FieldByName ( PKValues[0].Name ) ;
            i := 0 ;
            while not EOF do
            begin
               Searches[i] := FieldValue.Value ; // только первое поле, переделать, если ключ из нескольких полей
               inc ( i ) ;
               MoveBy ( 1 ) ;
            end ;

            ApplyFilterControls ( OnFieldName , '' , true ) ;
         finally
            CBCompare.ItemIndex := ItemIndex ;
            if assigned ( bmk ) then
            begin
               GotoBookmark ( bmk ) ;
               FreeBookmark ( bmk ) ;
            end ;
            EnableControls ;
            AfterScroll := ac ;
            SearchIndex := 0 ;
         end ;
      end ;

      if length ( Searches ) > SearchIndex then
      begin
         Locate ( GetParamNames ( PKValues ) , Searches[SearchIndex] , [loCaseInsensitive] ) ;
         inc ( SearchIndex ) ;
      end
      else
      begin
         ShowMessage ( 'Больше ничего не найдено' ) ;
         SearchIndex := 0 ;
      end ;
   end ;}
end ;

function TSQLFilterUIFast.GetFilterValueModified : boolean ;
begin
//   Result := FFilterValueModified or EParam.Modified ;
end ;

procedure TSQLFilterUIFast.FilterChange(Sender: TObject);
begin
   FFilterValueModified := true ;
end;

procedure TSQLFilterUIFast.LBComparisonSelectionChange(Sender: TObject; User: boolean);
begin
   if ( Sender is TListBox ) then
   begin
      DBLEValue.Enabled := ( 1 <= TListBox ( Sender ).ItemIndex ) ;
      if not DBLEValue.Enabled then DBLEValue.Text := '' ;
   end ;
end ;

////////////////////////////////////////////////////////////////////////////////////////////////////
function InitQuickFilterNew ( DBG : TDBGrid ; WithList , SmartFilter : boolean ) : TSQLFilterUIFast ;
var proc : procedure ( Column : TCollectionItem ) of object ; // для совместимости с другими гридами, где нет TColumn
begin
//   if not assigned ( DSQLFlt.SQL    ) then raise Exception.Create ( 'DataSet не имеет свойства SQL'         ) ;
//   if not assigned ( DSQLFlt.DBGrid ) then raise Exception.Create ( 'Окно фильтра работает только с гридом' ) ;

   if not assigned ( SQLFilterUIFast ) then
   begin
      Application.CreateForm ( TSQLFilterUIFast , SQLFilterUIFast ) ;
      with SQLFilterUIFast do
      begin
         //SQLFilter := DSQLFlt ;

         {CBList.Visible := WithList ;
         EParam.Visible := not WithList ;
         Bevel1.Visible := not WithList ;}

{         if WithList then
         begin
            Constraints.MinWidth  := Width ;
            Width  := ( Width * 3 ) div 2 ; // todo определять по типу и максимальной ширине фильтруемого поля, которую можно найти в OnCalcFields
            Height := Height * 2 - ClientHeight ;
            Constraints.MinHeight := Height ;
            Constraints.MaxHeight := Height ;
         end;
}
         //FProcSaveTitleClick := SQLFilter.DBGrid.OnTitleClick ;
         FPopupProcessed := false ;
         //proc := DBGTitleClick ;
         //SQLFilter.DBGrid.OnTitleClick := TDBGridClickEvent ( proc ) ;

         {with SQLFilter.DBGrid.PopupMenu do
            if assigned ( PopupMenu ) and assigned ( OnPopup ) then
            begin
               FProcSavePopup := OnPopup ;
               OnPopup        := OnPopupEvent ; // если на гриде нет попапа, а есть на его паренте, то клик по титлу грида будет неизбежно вызывать окно фильтра
            end ;}
         FSmartFilterSign := SmartFilter ;
      end ;
   end ;

   DBG.OnTitleClick      := @SQLFilterUIFast.DBGTitleClick ;
   DBG.OnDrawColumnTitle := @SQLFilterUIFast.DrawColumnTitle ;
   DBG.OnMouseLeave      := @SQLFilterUIFast.MouseLeave ;
   DBG.OnMouseMove       := @SQLFilterUIFast.MouseMove ;

   DM1.CacheFilter ( DBG.DataSource.DataSet ) ;
end ;

procedure TSQLFilterUIFast.DrawColumnTitle(Sender: TObject; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var bFilter : boolean = false ;
    sOrderBy : string = '' ;
begin
   if not ( Sender is TDBGrid ) then Exit ;
   DBG := TDBGrid ( Sender ) ;
   //State <> gdFixed

   DM1.GetFilterOrder ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , bFilter , sOrderBy ) ;

   if bFilter or ( sOrderBy <> '' ) then
      DrawFilterOrder ( DBG , Rect , Column , [gdFixed] , bFilter , sOrderBy ) ;
end ;

procedure TSQLFilterUIFast.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
const CLEARED       = -1 ;
      ORDERZA       = -2 ;
      ORDERAZ       = -3 ;
      FILTER        = -4 ;
      FILTERORDERZA = -5 ;
      FILTERORDERAZ = -6 ;
var R : TRect ;
    iCol : integer = 0 ;
    iRow : integer = 0 ;
    i : integer ;
    Column : TColumn ;
    bFilter : boolean = false ;
    sOrderBy : string = '' ;
    FO : TIsFilterOrder ;
    DBGCols : TDBGridColumns ;
begin // todo при resize колонке она разъезжается
   if not ( Sender is TDBGrid ) then Exit ;

   DBG := TDBGrid ( Sender ) ;
   DBGCols := DBG.Columns ;
   DBG.MouseToCell ( X , Y , iCol , iRow ) ;
   R := DBG.CellRect ( iCol , iRow ) ;

   iCol := iCol - DBG.FixedCols ; // TGridColumns -> TDBGridColumns
   iRow := iRow - {%H-}TCustomGridHack ( DBG ).FixedRows ;

   for i := 0 to DBGCols.Count - 1 do
      if ( i <> iCol ) or ( 0 <= iRow ) then
      begin
         Column := DBGCols.Items[i] ;
         if Column.Visible and ( Column.Title.ImageIndex <> CLEARED ) then
         begin
            Column.Title.ImageIndex := CLEARED ;

            {%H-}TCustomGridHack ( DBG ).DrawCell ( i , iRow , DBG.CellRect ( i , iRow ) , [gdFixed] ) ; // todo как снять рисунок или перейти на TShape? тогда где хранить их список?
         end ;
      end ;

   if ( DBG.MouseToGridZone ( X , Y ) = gzFixedCols ) and ( 0 <= iCol ) and ( iCol <= DBGCols.Count - 1 ) then
   begin
      Column := DBGCols.Items[iCol] ;
      FO := IsForFilterOrder ( X , R ) ;
      if FO <> [] then
      begin // слева подсветка фильтра, справа подсветка сортировки, посередине подсветку обоих не делаем
         DM1.GetFilterOrder ( TSQLQuery ( DBG.DataSource.DataSet ).SQL , Column.FieldName , bFilter , sOrderBy ) ;

         if sOrderBy = '' then sOrderBy := cAsc ;

         if not ( IsFilter in FO ) and ( IsOrder in FO ) then
            if sOrderBy = cDesc then
               i := ORDERZA
            else
               i := ORDERAZ
         else
               if ( IsFilter in FO ) and not ( IsOrder in FO ) then
                  i := FILTER
               else
                 if ( IsFilter in FO ) and ( IsOrder in FO ) then
                    if sOrderBy = cDesc then
                       i := FILTERORDERZA
                    else
                       i := FILTERORDERAZ ;

         if ( Column.Title.ImageIndex <> i ) or ( Column.Title.ImageIndex <> CLEARED ) then
         begin
            {%H-}TCustomGridHack ( DBG ).DrawCell ( iCol , iRow , DBG.CellRect ( iCol , iRow ) , [gdFixed] ) ;
            Column.Title.ImageIndex := i ;
         end ;

         if not ( IsOrder in FO ) then sOrderBy := '' ;
         if not ( IsFilter in FO ) or ( sOrderBy = '' ) then DrawFilterOrder ( DBG , R , Column , [gdHot] , ( IsFilter in FO ) , sOrderBy ) ;
      end ;
   end ;
   Application.ProcessMessages ; // иначе не отрисовывает сразу
end ;

procedure TSQLFilterUIFast.MouseLeave(Sender: TObject);
begin
   if ( Sender is TDBGrid ) and assigned ( TDBGrid ( Sender ).OnMouseMove ) then TDBGrid ( Sender ).OnMouseMove ( Sender , [] , 0 , 0 ) ; // стираем горячие пиктограммы минифильтра
end;

procedure TSQLFilterUIFast.DrawFilterOrder(DBG : TDBGrid ; const Rect: TRect; Column: TColumn; State: TGridDrawState ; bFilter : boolean ; sOrderBy : string );
var C : TColor ;
    dx : integer ;
    P : array[0..6] of TPoint ;
    BCSav , PCSav : TColor ;
begin
   with {%H-}TCustomGridHack ( DBG ) do
   begin //dbgrid1.Columns[0].Title.ScaleFontsPPI();
      BCSav := Canvas.Brush.Color ;
      PCSav := Canvas.Pen.Color ;

      try
         C := Column.Title.Font.Color ;
         if C = clDefault then C := GetDefaultColor ( dctFont ) ;
         Canvas.Brush.Color := C ;

         if bFilter then
            with Rect do
            begin
               dx := Left - Height div 8 ;
               P[0].x := Height div 8 + dx ; P[1].x := Height div 3 + Height div 10 + dx ; P[2].x := P[1].x                ; P[3].x := Height - Height div 3 - Height div 10 + dx ; P[4].x := P[3].x ; P[5].x := Height - Height div 8 + dx ; P[6].x := P[0].x ;
               P[0].y := Height div 6      ; P[1].y := Height div 2                      ; P[2].y := Height - Height div 4 ; P[3].y := P[2].y                                     ; P[4].y := P[1].y ; P[5].y := P[0].y                     ; P[6].y := P[0].y ;
               if gdFixed in State then begin Canvas.Pen.Color := Brush.Color ; Canvas.Polygon ( P , true ) ; end ;
               if gdHot   in State then begin Canvas.Pen.Color := C           ; Canvas.Polyline ( P )       ; end ;
            end ;

         if sOrderBy <> '' then
            with Rect do
            begin
               dx := Height div 7 ;
               P[0].x := Right - ( Height - Height div 7 ) - dx ; P[1].x := Right - ( Height - Height div 7 ) div 2 - dx ; P[2].x := Right - dx ; P[3].x := P[0].x ;
               if sOrderBy = 'asc' then
                  begin P[0].y := Height - Height div 3         ; P[1].y := Height div 4          ; end
               else
                  begin P[0].y := Height div 4                  ; P[1].y := Height - Height div 3 ; end ;
                                                                                                                           P[2].y := P[0].y     ; P[3].y := P[0].y ;
               if gdFixed in State then begin Canvas.Pen.Color := Brush.Color ; Canvas.Polygon ( P , true , 0 , 4 ) ; end ;
               if gdHot   in State then begin Canvas.Pen.Color := C           ; Canvas.Polyline ( P , 0 , 4 )       ; end ;
            end ;
      finally
         Canvas.Brush.Color := BCSav ;
         Canvas.Pen.Color   := PCSav ;
      end ;
   end ;
end ;

end.
