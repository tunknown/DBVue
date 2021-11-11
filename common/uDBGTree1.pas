unit uDBGTree1 ;
// components of tree-grid

interface

uses
   Windows, Classes , Graphics, Grids, DBGrids, DB, Forms , StdCtrls , Controls ,
   MemDS , {$IFNDEF FPC}MSAccess{$ELSE}sqldb{$ENDIF} ,
   DBGridsMy{strictly after DBGrids} ,
   common ;

const ARROWSIZE  : integer = 15 ;
      MARK       : integer = 1 ;
//      MARKPARENT : integer = 2 ;
      TREEBUTTONFONT = 'Marlett' ;
      FONTSIZEMARK = 6 ;

      TORIGHT  : PChar = '4' ;
      TODOWN   : PChar = '6' ;
      MARKED   : PChar = 'b' ;
      UNMARKED : PChar = 'r' ;

{$IF (Defined(RTLVersion) and (RTLVersion >= 20.0)) or defined(FPC)}
const EmptyBookmark = nil ;
type TBookmarkType = TBookmark ; // in delphi 2009+ type changed to TBytes
{$ELSE}
const EmptyBookmark = '' ;
type TBookmarkType = TBookmarkStr ;
{$IFEND}

type
   TDBGTreeNode = record
                     Level     : smallint ;
                     Bookmark  : TBookmarkType ;
                     Inactive  : boolean ;
                     Collapsed : boolean ; // used for search: 1=found records, 0=path to root records
                  end ;
   PDBGTreeNode = ^TDBGTreeNode ;

   TExpandMode = ( emExpand , emCollapse , emCollapseHide , emInvert ) ;
   TColumnType = ( ctCaption , ctMark , ctCustom ) ;

   TSQLQuery = class ( {$IFDEF FPC}SQLDB.TSQLQuery{$ELSE}TMSQuery{$ENDIF} ) // ����� ���� �� ����� ���� ������ ������ ��� ������������� TSQLQuery ������ TMSQuery
   private
      PKValue : variant ;         // ��� ������� ����� Id � ParentId/MasterId ���������� ������
      Level : integer ;           // ��� ������� ����� Level � ParentId/MasterId ���������� ������

      ChildrenVisible ,           // ��� ���������� ����� �������� �� ������ ������ ������� �������
      Inactive : variant ;        // ��� ���������� ����� �������� �� ������ ������ ������� �������


      FFChildrenVisible ,         // null=no children,0=collapsed,1=expanded; todo: if migrate to use ChildrenCount, then no saving ChildrenVisible is needed
      FFVisible ,                 // using for local filter
      FFInactive ,                // displaying search result upper path for parent of found record
      FFFertile : TBooleanField ; // creating new records only for even empty branch but not leaf

      FFLevel : TSmallintField ;  // navigating upper path
      FFId ,
      FFParent ,
      FFCaption ,                 // intention for tree by level
      FFMark : TField ;
   public
      procedure DoBeforeOpen       ; override ;
      procedure DoAfterOpen        ; override ;
      procedure DoBeforeInsert     ; override ;
      procedure DoAfterInsert      ; override ;
      procedure DoBeforeDelete     ; override ;// delete ChildrenVisible<>null
      procedure DoAfterDelete      ; override ;// delete ChildrenVisible<>null

      procedure DoAfterEdit        ; override ;
      procedure DoAfterCancel      ; override ;
      procedure DoAfterPost        ; override ;

      procedure InsertTree         ( Ig , Parent : TID ; Caption , RelationAlias : string ; IsParent : boolean = true ) ;
   end ;

   TDBGrid = class ( DBGrids.TDBGrid )
      function    LevelOffset       : integer ;
      procedure   DBGInplaceRect    ;
      function    GetTreeColumn     ( ct : TColumnType ) : TColumn ;
      procedure   CreateWnd         ; override ; // too early even in "Loaded"
   public
      constructor Create            ( AOwner : TComponent ) ; override ;
      procedure   DrawColumnCell    ( Sender : TObject ; const Rect : TRect ; DataCol : Integer ; Column : TColumn ; State : TGridDrawState ) ;
      procedure   CellClick         {$IFDEF FPC}(const aCol,aRow: Integer; const Button:TMouseButton){$ELSE}( Column : TColumn ){$ENDIF} ; override ;
      procedure   ColEnter          ( Sender : TObject ) ;
      procedure   KeyDown           ( var Key : Word ; Shift : TShiftState ) ; override ;
      procedure   KeyUp             ( var Key : Word ; Shift : TShiftState ) ; override ;
      procedure   MouseUp           ( Button : TMouseButton ; Shift : TShiftState ; X , Y : Integer ) ; override ;

      class function UpLevelInternal ( FieldLevel : TField ) : integer ;
      function    UpLevel           : integer ;

      procedure   Prepare           ;
      procedure   Expand            ( Mode : TExpandMode = emInvert ; bmk : TBookmarkType = EmptyBookmark ; LFilter : TList = nil ) ;
      function    Search            ( DSSearch : TSQLQuery ; Ig : TID ; Desc : string = '' ; Condition : string = '' ) : integer ;
      procedure   Enmark            ;

      //procedure Refresh           ; // todo: ��������� ������ ���������� �����, ��������� ������� � ������������� ��; ����� ��� ��������� ������ ������ �������������, ��� ���� �������� ��������� ������������ � �����������

      function    SetMark           ( s : string ) : integer ;
      function    GetMark           ( SelectedIfEmpty : boolean = true ) : string ;
   end;

implementation

uses
   SysUtils , Dialogs ,
   commonDS , commonCTRL ;

{$IFNDEF FPC}
type
   TCustomEditHack = class ( TCustomEdit ) ;
{$ENDIF}
////////////////////////////////////////////////////////////////////////////////////////////////////
constructor TDBGrid.Create ( AOwner : TComponent ) ;
begin
   inherited Create ( AOwner ) ;

   OnDrawColumnCell := @DrawColumnCell ;
   OnColEnter := @ColEnter ;
end ;

procedure TDBGrid.CreateWnd;
begin
   inherited ;

   Prepare ;
end ;

function TDBGrid.GetTreeColumn ( ct : TColumnType ) : TColumn ;
var i : integer ;
type TS = set of TFieldType ;

   function IsColumnField ( c : TColumn ; SS : TS ) : boolean ;
   begin
      Result :=     assigned ( c.Field )
                and c.Field.Visible
//                and ( c.Field.FieldKind = fkData )
                and ( c.Field.DataType in SS ) ;
   end ;

begin // ������ ������� � ������� ����� ������� ������ ��� ������; ������� ������� ������� ���� � ������� ��������� ������������� �� �����
   if assigned ( Columns ) then
      with Columns do
         for i := 0 to Count - 1 do
         begin
            Result := Items[i] ;

            case ct of // todo ����� �� ��������� Visible?
               ctCaption :
                  if IsColumnField ( Result , [ftString , ftWideString] ) and ( Result.Field = TSQLQuery ( DataSource.DataSet ).FFCaption ) then Exit ;
               ctMark :
                  if IsColumnField ( Result , [ftWord]                  ) and ( Result.Field = TSQLQuery ( DataSource.DataSet ).FFMark    ) then Exit ;
               ctCustom :
                  Exit ;
            end ;
         end ;

   Result := nil ;
end ;

function TDBGrid.LevelOffset : integer ;
begin
   Result := trunc ( DefaultRowHeight * TSQLQuery ( DataSource.DataSet ).FFLevel.AsInteger {* 4 / 3} ) + ARROWSIZE ; // ������ ������� � 4/3 ������ ������ ����� �� ������ ������������ ������ Windiws � �������������
end ;

procedure TDBGrid.DBGInplaceRect ;
var offset : integer ;
begin
   if not assigned ( InplaceEditor ) then Exit ;

   offset := LevelOffset ;
   with InplaceEditor do
   begin
//      BorderStyle := bsSingle ;
      Left  := Left  + offset ;
      Width := Width - offset ;
   end ;
end ;

procedure TDBGrid.ColEnter ( Sender : TObject ) ;
var IsTreeColumn : boolean ;
begin
   if Columns.Count > 0 then
   begin
      IsTreeColumn := ( Columns[SelectedIndex] = GetTreeColumn ( ctCaption ) ) ;
      if not IsTreeColumn or ( DataSource.State in [dsInsert , dsEdit] ) then
      begin
         Options := Options + [dgEditing] ; // ������� �� ��������������� ������ ��������, � �� �������, ��� �������������� ������ ���� ��������

         if IsTreeColumn then DBGInplaceRect ;
      end
      else
         Options := Options - [dgEditing] ;
   end ;

   inherited ;
end;

procedure TDBGrid.MouseUp ( Button : TMouseButton ; Shift : TShiftState ; X , Y : Integer ) ;
begin
   if     ( Columns.Count > 0 )
      and ( Columns[SelectedIndex] = GetTreeColumn ( ctCaption ) ) then
      DBGInplaceRect ;

   inherited ;
end;

procedure TDBGrid.DrawColumnCell ( Sender : TObject ; const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);

   function VerticalAlign : integer ; inline ;
   begin
      Result := ( DefaultRowHeight - ( -Canvas.Font.Height ) ) div 2 ;
   end ;

var x , y , FontSizeSav : integer ;
    cSymb : PChar ;
    FontNameSav : TFontName ;
    FontStyleSav : TFontStyles ;
    FontColorSav : TColor ;
    Rect1 : TRect ;
    Flags : UINT ;
    CMark : TColumn ;
    IsMarked {, IsMarkedParent} : boolean ;
begin
   if not assigned ( Column ) then Exit ;

   with Canvas do
   begin
      CMark := GetTreeColumn ( ctMark ) ;

      IsMarked := assigned ( CMark ) and ( CMark.Field.AsInteger and MARK = MARK ) ;

      if GetTreeColumn ( ctCaption ) = Column then
      begin
         FontColorSav := Font.Color ;
         FontStyleSav := Font.Style ;

         try
            Font.Style := [] ;

            if IsMarked and not ( gdSelected in State ) {$IF Declared(RTLVersion) and (RTLVersion >= 20.0)}and not ( gdRowSelected in State ){$IFEND} then
            begin
               Brush.Color := clMenuHighlight ; // ����� FillRect
               Font.Color  := clCaptionText ;
            end ;

            if TSQLQuery ( DataSource.DataSet ).FFInactive.AsBoolean then
               Font.Color := clGrayText ;

            FillRect ( Rect ) ; // �������� ������, ���� � ��� ��� ���������� ����� �� ���������

            SetBkMode ( Handle , TRANSPARENT ) ;

            Rect1 := Rect ;
            Rect1.Left := Rect.Left + LevelOffset ;

            with TSQLQuery ( DataSource.DataSet ).FFChildrenVisible do // ���������� ��������
               if not IsNull then
               begin
                  if AsBoolean then cSymb := TODOWN else cSymb := TORIGHT ;

                  FontSizeSav := Font.Size ;
                  FontNameSav := Font.Name ;

                  try
                     Font.Name  := TREEBUTTONFONT ;
                     Font.Size  := 10 ;

                     ExtTextOut ( Handle ,
                                  Rect1.Left - ARROWSIZE{TextWidth ( TODOWN )},
                                  Rect.Top + VerticalAlign ,
                                  0 ,
                                  @Rect ,
                                  cSymb ,
                                  Length ( cSymb ) ,
                                  nil ) ;
                  finally
                     Font.Size  := FontSizeSav ;
                     Font.Name  := FontNameSav ;
                  end ;
               end ;

            //IsMarkedParent := assigned ( CMark ) and ( CMark.Field.AsInteger and MARKPARENT = MARKPARENT ) ;
            if IsMarked {or IsMarkedParent} then Font.Style := [fsBold] ;

            DefaultDrawColumnCell ( Rect1 , DataCol , Column , State ) ; // ExtTextOut
         finally
            Font.Style := FontStyleSav ;
            Font.Color := FontColorSav ; // ������������ ������ ����� DefaultDrawColumnCell
         end ;
      end ;

      if assigned ( CMark ) and ( CMark = Column ) then
      begin
         FontColorSav := Font.Color ;
         FontSizeSav  := Font.Size ;
         FontNameSav  := Font.Name ;
         FontStyleSav := Font.Style ;
         Flags := GetTextAlign ( Handle ) ;

         try
            Font.Name  := TREEBUTTONFONT ;
            Font.Size  := FONTSIZEMARK ; //����������� ����������: MARKED{FontSize=9,x=x-1},UNMARKED{FontSize=6,y=y+1};MARKED{FontSize=5,x=x+1},UNMARKED{FontSize=4,y=y+1}
            Font.Style := [] ;
            Font.Color := clGrayText ;
            SetTextAlign ( Handle , TA_CENTER ) ; // ����������� ����������� �� �����

            x := ( Rect.Left + Rect.Right  ) div 2 + 1 ;
            y := ( Rect.Top  + Rect.Bottom ) div 2 - VerticalAlign + 1 ;

            if IsMarked then
            begin
               cSymb := MARKED ;
               x := x - 1 ;
               Font.Size := Font.Size + 3 ;
            end
            else
            begin
               cSymb := UNMARKED ;
               y := y + 1 ;
            end ;

            FillRect ( Rect ) ; // �������� ������, ���� � ��� ��� ���������� ����� �� ���������

            ExtTextOut ( Handle ,
                         x ,
                         y , // ����������� ����������� �� �����, ������� �������
                         0 ,
                         @Rect ,
                         cSymb ,
                         Length ( cSymb ) ,
                         nil ) ;
         finally
            Font.Color := FontColorSav ;
            Font.Size  := FontSizeSav ;
            Font.Name  := FontNameSav ;
            Font.Style := FontStyleSav ;
            SetTextAlign ( Handle , Flags ) ;
         end ;
      end ;
   end ;
end ;

class function TDBGrid.UpLevelInternal ( FieldLevel : TField ) : integer ;
var l : integer ;
begin
   Result := GetIntFieldData ( FieldLevel ) ;

   with FieldLevel.DataSet do
      repeat  // ���� �� �������� ������
         MoveBy ( -1 ) ;
         l := GetIntFieldData ( FieldLevel ) ;
      until ( Result > l ) or ( l = 0 ) or BOF ; // ���� Level = 0, �� ����������� ���� ��� ������, �������� �� GotoBookMark

   Dec ( Result ) ;
end ;

function TDBGrid.UpLevel : integer ;
var AfterScrollSave : TDataSetNotifyEvent ;
begin
   Result := -1 ;
   if not assigned ( DataSource.DataSet ) then Exit ;

   with TSQLQuery ( DataSource.DataSet ) do
   begin
      AfterScrollSave := AfterScroll ;
      try
         AfterScroll := nil ;
         DisableControls ;

         Result := UpLevelInternal ( FFLevel ) ;
      finally
         EnableControls ;
         AfterScroll := AfterScrollSave ;
         if assigned ( AfterScroll ) then AfterScroll ( DataSource.DataSet ) ;
      end ;
   end ;
end ;

procedure TDBGrid.Enmark ;
var C : TColumn ;
    F : TField ;
    NewMarking : smallint ;
begin
   C := GetTreeColumn ( ctMark ) ;

   if not assigned ( C ) or not assigned ( C.Field ) then Exit ;

   F := C.Field ;
   NewMarking := F.AsInteger xor MARK ;

   with TMemDataSet ( F.DataSet ) do
      try
         DisableControls ;
//         LocalUpdate := true ; // SDAC only

         Edit ;
         F.AsInteger := NewMarking ;
         Post ;

{         while UpLevelInternal ( FFLevel ) >= 0 do
         begin
            Edit ;

            if NewMarking and MARK = MARK then
               F.AsInteger := F.AsInteger or MARKPARENT
            else
               F.AsInteger := F.AsInteger and not MARKPARENT ;
            Post ;
         end ;}
      finally
//         LocalUpdate := false ; // SDAC only
         EnableControls ;
      end ;
end ;

function TDBGrid.SetMark ( s : string ) : integer ;
const GUIDLEN = 36 ; // length(GUID)
var i : integer ;
begin
{$IFNDEF FPC}
   Result := 0 ;
   s := StringReplace ( StringReplace ( s , '{' , '' , [rfReplaceAll] ) , '}' , '' , [rfReplaceAll] ) ;

   if Length ( s ) mod GUIDLEN <> 0 then Exit ;

   for i := ( length ( s ) div GUIDLEN ) - 1 downto 0 do
      if Search ( nil , GUID ( Variant ( copy ( s , i * GUIDLEN + 1 , GUIDLEN ) ) ) ) > 0 then //      if DBG.DataSource.DataSet.Locate ( 'Id' , copy ( s , i * GUIDLEN + 1 , GUIDLEN ) , [loCaseInsensitive , loPartialKey{����� �� ������ �� ��������}] ) then
      begin
         inc ( Result ) ;
         Enmark ; // ����� ����� ������� ������ � �������� �� ������ ������ �� �������� ������ ������
      end ;
{$ENDIF}
end ;

function TDBGrid.GetMark ( SelectedIfEmpty : boolean = true ) : string ;
var DC : TDataChangeEvent ;
    ASC : TDataSetNotifyEvent ;
    F : TField ;
    c : TColumn ;
    s : string ;
    bmk : TBookmark ;
    FilteredSave : boolean ;
begin
   c := GetTreeColumn ( ctMark ) ;
   if not assigned ( c ) or not assigned ( c.Field ) then Exit ;
   F := c.Field ;

   with DataSource , TSQLQuery ( Dataset ) do
   begin
      bmk := GetBookmark ;

      DC := OnDataChange ;
      ASC := AfterScroll ;

      OnDataChange := nil ;
      AfterScroll := nil ;

      s := '' ;

      FilteredSave := Filtered ;
      try
         DisableControls ;

         Filtered := false ;

         First ;
         while not EOF do
         begin
            if F.AsInteger and MARK = MARK then s := s + FFId.AsString ;
            Next ;
         end ;
      finally
         Filtered := FilteredSave ;

         GotoBookmark ( bmk ) ;
         FreeBookmark ( bmk ) ;

         OnDataChange := DC ;
         AfterScroll := ASC ; // ��������������� ����� GotoBookmark, ����� �� ����������� ������� ���������� ��������

         EnableControls ;
      end ;

      if ( s = '' ) and SelectedIfEmpty then
         Result := FFId.AsString
      else
         Result := s ;
   end ;
end ;

procedure TDBGrid.KeyDown ( var Key : Word ; Shift : TShiftState ) ;
begin
   if ( dgRowSelect in Options ) and ( Key in [VK_LEFT , VK_RIGHT] ) then Key := 0 ;

   inherited ;
end ;

procedure TDBGrid.KeyUp ( var Key : Word ; Shift : TShiftState ) ;
begin
   if     ( Key in [VK_LEFT , VK_RIGHT , VK_RETURN , VK_SPACE] )
      and assigned ( DataSource )
      and ( DataSource.State = dsBrowse ) then // ������ �� ��� �������������� � ������
      with DataSource , TSQLQuery ( DataSet ) do
         case Key of
            VK_LEFT :
               if FFChildrenVisible.AsBoolean then Expand ( emCollapse ) else UpLevel ;
            VK_RIGHT :
               if FFChildrenVisible.AsBoolean then Next else Expand ( emExpand ) ;
            VK_RETURN :
               Expand ;
            VK_SPACE :
               begin
                  Enmark ;
                  Next ;
               end ;
         end ;

//   Key := 0 ; // ����� �� ��������, ����� ��������� OnKeyDown // �������, ��� ���������� � � ���� �� �����

   inherited ;
end;

procedure TDBGrid.Expand ( Mode : TExpandMode = emInvert ; bmk : TBookmarkType = EmptyBookmark ; LFilter : TList = nil ) ;
var Level1 , l : integer ;
    AfterScrollSave : TDataSetNotifyEvent ;
    Expanding , FilteredSave , EOFSave : boolean ;

   procedure EditPost ;
   var i , idx : integer ;
       b : {word}boolean ;
   begin
      idx := -1 ;

      with TSQLQuery ( DataSource.DataSet ) do
      begin
         if assigned ( LFilter ) then
            for i := 0 to LFilter.Count - 1 do
               if CompareBookmarks ( TBookmark ( Bookmark ) , TBookmark ( TDBGTreeNode ( LFilter[i]^ ).Bookmark ) ) = 0 then // ���������� TBookmarkStr �� ������ �����, �.�. ����� ��������� �������� � ��������� ��� ����� ��������� ����������, �� ��������� �� ���� ������, �.�. SLFilter.IndexOf ( bmk ) �� ���������
               begin
                  idx := i ;
                  break ;
               end ;

         InternalEdit ;        // Edit ��������� � �������� ������ ����� DoAfterEdit
         SetState ( dsEdit ) ; // ������ Edit

         b :=     (  ( Mode <> emCollapseHide ) and ( l = Level1     )
                  or Expanding                  and ( l = Level1 + 1 ) )
              and ( not assigned ( LFilter ) or ( idx > -1 ) ) ;

         //SetFieldData ( FFVisible , @b ) ; // ��������� �������, ��� FieldVisible.AsBoolean
         FFVisible.AsBoolean := b ;

         if idx > -1 then
         begin
            b := TDBGTreeNode ( LFilter[idx]^ ).Inactive ;
            //SetFieldData ( FFInactive , @b ) ; // SetFieldData ( FieldInactive , @( TDBGTreeNode ( LFilter[idx]^ ).Inactive ) ) ����������� �� ������ ���������
            FFInactive.AsBoolean := b ;
         end
         else
            SetFieldData ( FFInactive , nil ) ;

         if not FFChildrenVisible.IsNull then
         begin
            b := Expanding and ( l = Level1 ) ;
            //SetFieldData ( FFChildrenVisible , @b ) ;
            FFChildrenVisible.AsBoolean := b ;
         end ;

         InternalPost ;           // �������� ������� � 2 ���� ������ Post
         FreeFieldBuffers ;       // �������� ������� � 2 ���� ������ Post
         SetState ( dsBrowse ) ;  // �������� ������� � 2 ���� ������ Post
      end ;
   end ;

begin
   with TSQLQuery ( DataSource.DataSet ) do
   begin
      if bmk = EmptyBookmark then bmk := Bookmark else Bookmark := bmk ;

      with FFChildrenVisible do
         if    ( Mode = emExpand        ) and     AsBoolean
            or ( Mode = emCollapse      ) and not AsBoolean
            or ( Mode <> emCollapseHide ) and IsNull then Exit ; // ��� ����� ���������� Bookmark

      FilteredSave := Filtered ;
      AfterScrollSave := AfterScroll ;
      try
         AfterScroll := nil ;

         DisableControls ;

         Expanding := ( ( Mode = emInvert ) and not FFChildrenVisible.AsBoolean ) or ( Mode = emExpand ) ; // ���� ��� ��������� ������������ ��������

         Filtered := false ; // ����� �������� // ���� SDAC 3.80.0.38 ��������, ��� ��� ���� ����������� � �������, � �� ������ �� �������, �� Filtered := false ������� ������� ������� � ������� � ������ ������

         if FilteredSave then Bookmark := bmk ; // TBookmark ������������ ������, �.�. GotoBookmark �� ����� ��������� "������" ������ �� � ����� ������ �������

         Level1 := GetIntFieldData ( FFLevel ) ;
         l     := Level1 ;

//         LocalUpdate := true ; // SDAC only
         repeat
            if    ( l in [Level1 , Level1 + 1] ) // ���������� ���������������� �������� � ����
               or FFVisible.AsBoolean then  // �������� ����, � �.�. � �������� ����� ������ ������, ��� ��� ���������� �������� � ������� ���������� �����
               EditPost ;

            MoveBy ( 1 ) ; // ��������� ��� ��������� DataSet.GetNextRecord �� ����������
            l := GetIntFieldData ( FFLevel ) ;
         until ( l <= Level1 ) or EOF ; // ������� ����� ���� ��������� �� ������ ��� Level1 + 1
      finally
//         LocalUpdate := false ;
         EOFSave := EOF ;
         Filtered := FilteredSave ;
         if Mode <> emCollapseHide then // ���� ��������, �� ������� �� ���� �� ����� �� ���������
            Bookmark := bmk
         else
            if EOFSave then Last ; // ������� EOF ����� �������������� �������
         EnableControls ;

         AfterScroll := AfterScrollSave ;
      end ;
   end ;
end ;

procedure TDBGrid.CellClick{$IFDEF FPC}(const aCol,aRow: Integer; const Button:TMouseButton){$ELSE}( Column : TColumn ){$ENDIF};
var CP : TPoint ;
    R : TRect ;
    {$IFDEF FPC}Column : TColumn ;{$ENDIF}
//ERRATA ���� �������� ����� ����� dgRowSelect, �� Column.Index = 0 ��� ������ �� ������ �������, ������� ����������� �������������� ������ �� ������ �� ����� �������
begin
   {$IFDEF FPC}Column := TColumn ( ColumnFromGridColumn ( aCol ) ) ;{$ENDIF}
   if assigned ( Column ) then
   begin
      CP := ScreenToClient ( Mouse.CursorPos ) ;

      R := CellRect ( aCol , aRow ) ;

//      MC := MouseCoord ( CP.X , CP.Y ) ;
//      if dgRowSelect in Options then Column := Columns[MC.X] ; // ���� � ����� ����� dgRowSelect, �� Column ������ ������ �� �����, � ����� ����� ����� ����� ������

      if GetTreeColumn ( ctCaption ) = Column then
         if CP.X - {CellRect ( MC.X , MC.Y )}R.Left <= LevelOffset then Expand ; // ������������� ������ ������ �� ����� �� ����� ����� �� ������

      if GetTreeColumn ( ctMark ) = Column then Enmark ;
   end ;

   inherited ;
end ;

procedure TDBGrid.Prepare ;
var OptionsSave : TDBGridOptions ;
    RowHeightSave : integer ;
    c : TColumn ;
begin
   OptionsSave := Options ;

   if dgRowLines in Options then RowHeightSave := DefaultRowHeight else RowHeightSave := 0 ; // ����� ��� ���������� ����� ������ ������ ���������� �������, ��������, ��� ����, ����� ��� �����, ������������� ����� ��������� ��������� �� �������

   DBGridEditing ( self , true ) ; // ��� �� ��� ������ ShowEditor ; // ����� ����� ������������ �������� InplaceEditor

   Options := OptionsSave ;

   Options := Options - [dgEditing{ , dgTitles , dgIndicator} , dgAlwaysShowEditor , dgRowLines , dgColLines] + [dgAlwaysShowSelection] ;
   if RowHeightSave <> 0 then DefaultRowHeight := RowHeightSave + 1 ;

   {$IFNDEF FPC}
   TCustomEditHack ( InplaceEditor{FPC:GetDefaultEditor ( 0 )} ).BorderStyle := bsSingle ; // �� ������� ���������� BorderStyle �������� InplaceEditor ��� ������ ������
   {$ENDIF}

   c := GetTreeColumn ( ctMark ) ;
   if assigned ( c ) then
      with c do
      begin
         Font.Name := TREEBUTTONFONT ; // ����� ������������ �������� ��������� ������� ������������
         Font.Size := FONTSIZEMARK ;
      end ;
end ;

function CompareFunc ( Item1 , Item2 : Pointer ) : Integer ;
begin
   Result := TDBGTreeNode ( Item1^ ).Level - TDBGTreeNode ( Item2^ ).Level ;
end ;

function TDBGrid.Search ( DSSearch : TSQLQuery ; Ig : TID ; Desc : string = '' ; Condition : string = '' ) : integer ;
var i , j , bmkCounter : integer ;
    AfterScrollSave : TDataSetNotifyEvent ;
    LBmk , LParam : TList ;
    FilterSave , s , IdFieldName : string ;
    FilteredSave , ShowInactive : boolean ;
    bmkFirst : TBookmarkType ;
    em , em2 : TExpandMode ;
    FieldLevel : TField ;
//ERRATA ���� ������ �� �������, �� �� ������� � ������� ������ �� ������

   procedure StoreBookmarks ( b : TBookmarkType ; Inactive , Collapsed : boolean ) ;
   var r : ^TDBGTreeNode ;
   begin
      if b <> EmptyBookMark then
      begin
         New ( r ) ; // � Delphi ����� �� ������ ^
         r^.Level := GetIntFieldData ( FieldLevel ) ; // �� ������ � ������ ����� ���������
         r^.Bookmark := b ;
         r^.Inactive := Inactive ;
         r^.Collapsed := Collapsed ;
         LBmk.Add ( r ) ;
      end ;
   end ;

   function LBmkSearch ( b : TBookmarkType ) : integer ;
   begin
      Result := LBmk.Count - 1 ;
      while ( Result >= 0 ) and ( {$IF Declared(RTLVersion) and (RTLVersion >= 20.0)}DataSet.CompareBookmarks ( TDBGTreeNode ( LBmk[Result]^ ).Bookmark , b ) <> 0{$ELSE}TDBGTreeNode ( LBmk[Result]^ ).Bookmark <> b{$IFEND} ) do
         Dec ( Result ) ; // ������������, � �������� ������� ������ �������, �.�. � ������ ������ ������ ���� ��������������� �������, � � ����� �� �������� ������������� ������
   end ;

begin
   if not assigned ( DSSearch ) then DSSearch := TSQLQuery ( DataSource.DataSet ) ;

   Result := 0 ;

   ShowInactive := GUIDEmpty ( Ig ) ;

   bmkFirst := EmptyBookmark ;

   if DSSearch <> DataSource.DataSet then FieldLevel := DataSource.DataSet.FieldByName ( DSSearch.FFLevel.FieldName ) else FieldLevel := DSSearch.FFLevel ; // ������������ � StoreBookmarks


















   LBmk := TList.Create ;

   try

      if DSSearch = DataSource.DataSet then
      begin
         FilteredSave := DSSearch.Filtered ;
         AfterScrollSave := DSSearch.AfterScroll ;

         try
            DSSearch.AfterScroll := nil ;

            DSSearch.DisableControls ;



            if ShowInactive then
            begin
               if Desc = '' then Exit ;

               s := DSSearch.FFCaption.FieldName + '=''*' + Desc + '*''' ; // SDAC only
            end
            else
            begin
               if assigned ( DSSearch.FFId ) then IdFieldName := 'Id' else IdFieldName := 'Id' ; // todo
               s := IdFieldName + '=''' + string ( EnGUID ( Ig ) ) + '''' ; // ��� integer ����?
            end ;

            if Condition <> '' then s := s + ' and (' + Condition + ')' ;



            FilterSave := DSSearch.Filter ;
            DSSearch.Filter     := s      ;
            DSSearch.Filtered   := true   ;

            Result := DSSearch.RecordCount ;

            if not ShowInactive and ( Result > 1 ) then Result := 1 ;

            if Result > 0 then
            begin
               LBmk.Capacity := Result * 3 ; // ��������, ������ ��������� ������� ����� ���� �������, ������� ���� ����� ��������

               DSSearch.First ; // ��� SDAC �����
               bmkFirst := DSSearch.Bookmark ; // ������ ��������� ������

               while not DSSearch.EOF do // ��������� ��� ��������������� ������
               begin
                  StoreBookmarks ( DSSearch.Bookmark , false , true ) ;
                  DSSearch.MoveBy ( 1 ) ;
               end ;
            end ;
         finally
            DSSearch.Filter   := FilterSave   ;
            DSSearch.Filtered := FilteredSave ;

            DSSearch.EnableControls ;

            DSSearch.AfterScroll := AfterScrollSave ;
         end ;


      end
      else
      begin
         with TSQLQuery ( DSSearch ) do
         begin



         FilteredSave := DataSource.DataSet.Filtered ;
         FilterSave   := DataSource.DataSet.Filter ;
         AfterScrollSave := DataSource.DataSet.AfterScroll ;

         try
            DataSource.DataSet.AfterScroll := nil ;

            DataSource.DataSet.DisableControls ;
            DataSource.DataSet.Filtered   := false   ;



            ParamByname ( 'Search' ).Value := '%' + Desc + '%' ;
            Active := false ;
            Active := true ;

            Result := DSSearch.RecordCount ;

            if not ShowInactive and ( Result > 1 ) then Result := 1 ;

            if Result > 0 then
               while not DSSearch.EOF do // ��������� ��� ��������������� ������
               begin
                  if DataSource.DataSet.Locate ( 'Id' , DSSearch.FieldByName ( 'Sequence' ).Value , [] ) then
                  begin
                     if bmkFirst = EmptyBookmark then bmkFirst := DataSource.DataSet.Bookmark ; // ��������� ��� �������� �� ������ ��������� ������
                     StoreBookmarks ( DataSource.DataSet.Bookmark , false , true ) ;
                  end ;

                  DSSearch.MoveBy ( 1 ) ;
               end ;

            //Active := false ; // ������� ������ ����� ������ �� �����, �� ������� ������� � ����������� ���?
         finally
            DataSource.DataSet.Filter   := FilterSave   ;
            DataSource.DataSet.Filtered := FilteredSave ;

            DataSource.DataSet.EnableControls ;

            DataSource.DataSet.AfterScroll := AfterScrollSave ;
         end ;


         end ;
      end ;


















      if Result > 0 then
      begin


         FilteredSave := DataSource.DataSet.Filtered ;
         AfterScrollSave := DataSource.DataSet.AfterScroll ;

         try
            DataSource.DataSet.AfterScroll := nil ;

            DataSource.DataSet.DisableControls ;

            try
               DataSource.DataSet.Filtered := false ;
               DataSource.DataSet.First ; // ��� SDAC �����

               bmkCounter := LBmk.Count - 1 ;
               for i := 0 to bmkCounter do // ��������� �������������� ����� ���������, ��� �������� ������� �� ���������� SLlvl.Count
               begin
                  DataSource.DataSet.Bookmark := TDBGTreeNode ( LBmk[i]^ ).Bookmark ; // ��������� ���� ������ ��� ��������� �������
                  TDBGTreeNode ( LBmk[i]^ ).Bookmark := DataSource.DataSet.Bookmark ; // ����� �������� ��� ��������� (Filtered := false) ��� SDAC ��������� �������������� ��������

                  while UpLevelInternal ( FieldLevel ) >= 0 do
                  begin
                     j := LBmkSearch ( DataSource.DataSet.Bookmark ) ;

                     if j = -1 then
                        StoreBookmarks ( DataSource.DataSet.Bookmark , ShowInactive , false ) // ����� ����� ���������� TBookmarkStr, �.�. ���� �� ���� �������� ��� ���������
                     else
                        TDBGTreeNode ( LBmk[j]^ ).Collapsed := false ; // ���� ������ ���� � ������ �������� ��������� � ����� �����, �� ��� ����� �������������
                  end ;
               end ;

               LBmk.Sort ( @CompareFunc ) ; // ��� ���������� �� Level ������ ��� Expand ������ � ���������� ������������������

               if ShowInactive then
               begin
                  LParam := LBmk ;
                  em := emCollapseHide ;
               end
               else
               begin
                  LParam := nil ;
                  em := emCollapse ;
               end ;

               DataSource.DataSet.First ;
               while not DataSource.DataSet.EOF do
               begin
                  Expand ( em ) ; // �������� �������� // Next �� �����, �.�. ���������� ������� "��������" ������ �����
                  if not ShowInactive then DataSource.DataSet.MoveBy ( 1 ) ;
               end ;

               for i := 0 to LBmk.Count - 1 do // �������� � ������� �������
               begin
                  if TDBGTreeNode ( LBmk[i]^ ).Collapsed then
                     em2 := emCollapse // ���� ��������� ������� � ���������, �� ��� ������ ���� �������, ���� � ��� ����� ��� ������ ��������� ��������
                  else
                     em2 := emExpand ;

                  Expand ( em2 , TDBGTreeNode ( LBmk[i]^ ).Bookmark , LParam )
               end ;
            finally
               for i := LBmk.Count - 1 downto 0 do
                  Dispose ( PDBGTreeNode ( LBmk[i] ) ) ;
            end ;
         finally
            DataSource.DataSet.Filter   := FilterSave   ;
            DataSource.DataSet.Filtered := FilteredSave ;

            DataSource.DataSet.EnableControls ;

            DataSource.DataSet.AfterScroll := AfterScrollSave ;

            if bmkFirst <> EmptyBookmark then DataSource.DataSet.Bookmark := bmkFirst ; // ��������� �� ������ ��������� ������
         end ;
      end ;
   finally
      if assigned ( LBmk ) then LBmk.Free ;
   end ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TSQLQuery.DoBeforeOpen;
begin
   PKValue := Null ;
   {$IFNDEF FPC}
   CachedUpdates := true ; // ������ LocalUpdate ��� ���������� ������������� � Lazarus
   {$ELSE}
   Options := Options - [sqoAutoApplyUpdates] ; // to ReadOnly deactivate needs filling TSQLQuery.InsertSQL/UpdateSQL/DeleteSQL with dumb
   {$ENDIF}

   inherited ;
end;

procedure TSQLQuery.DoAfterOpen;
var i : integer ;
    CaptionFound : boolean = false ;
begin
   inherited ;

   FFChildrenVisible := TBooleanField ( FieldByName ( 'ChildrenVisible' ) ) ;
   FFVisible         := TBooleanField ( FieldByName ( 'Visible'         ) ) ;
   FFInactive        := TBooleanField ( FieldByName ( 'Inactive'        ) ) ;
   FFLevel           := TSmallintField ( FieldByName ( 'Level' ) ) ;
   FFCaption         := FieldByName ( 'Caption'         ) ;

   FFFertile         := TBooleanField ( FindField ( 'Fertile'         ) ) ;
   FFId              := FindField ( 'Id'              ) ;
   FFParent          := FindField ( 'Parent'          ) ;
   FFMark            := FindField ( 'Mark'            ) ;

   DisableControls ; // ����� �� ���������� TDataSource.OnDataChange �� ��������� ������� ����
   try
      // todo ������� ����� ColumnizeGrid
      FFChildrenVisible.Visible := false ;
      FFVisible.Visible         := false ;
      FFInactive.Visible        := false ;
      FFLevel.Visible           := false ;
      FFCaption.Visible         := true ;

      if assigned ( FFFertile ) then FFFertile.Visible := false ;
      if assigned ( FFId      ) then FFId.Visible      := false ;
      if assigned ( FFParent  ) then FFParent.Visible  := false ;
      if assigned ( FFMark    ) then FFMark.Visible    := false ;

//   DBG := TDBGrid ( GetDataSetGrid ( nil , DataSet ) ) ;
//   if assigned ( DBG ) and assigned ( DBG.OnColEnter ) then DBG.OnColEnter ( DBG ) ; // � TDataSet.AfterOpen ��� �� ������� ������� � �����
      Filter := FFVisible.FieldName {$IFNDEF FPC}+ '=true'{$ENDIF} ; // in Lazarus filter by boolean field has only fieldname without value comparision
      FilterOptions := [foCaseInsensitive] ;
      Filtered := true ;

//   if assigned ( AfterScroll ) then AfterScroll ( DataSet ) ;

      for i := 0 to Fields.Count - 1 do // todo ���������� �� ColumnizeGrid
         with Fields[i] do
         begin
            ReadOnly := false ;
            Required := false ;
            if not CaptionFound then
            begin
               CaptionFound := ( FieldName = 'Caption' ) ; // ��� ���� ����� Caption ��������
               if not CaptionFound then Visible := false ;
            end ;

            if Visible then
               case DataType of
                  ftSmallint , ftInteger , ftWord , ftBoolean :
                     DisplayWidth := 5 ;
                  else
                     DisplayWidth := 25 ;
               end;
         end ;
   finally
      EnableControls ;
   end;
end;

procedure TSQLQuery.DoBeforeInsert;
var trueEOF : boolean ;
// ERRATA ���� �� ����� ����� ������ ������ �����, ���������� �� ���� DBGTree, �� ����� Edit ���������� TDataSourceMethods.OnStateChange ��������� �� �������� ���� � ����� �������������� ����������
begin // ��� ������ �� �����, ���������� ��������� � InsertTree
   if PKValue {%H-}= Null then // �������� ������������
   begin
      if not FFFertile.AsBoolean then
      begin
         while ( TDBGrid.UpLevelInternal ( FFLevel ) >= 0 ) and not FFFertile.AsBoolean do ;

         if not FFFertile.AsBoolean then Abort ;
      end ;

      PKValue         := FFId.Value              ; // ���������� ��� ������ �������
      Level           := FFLevel.AsInteger + 1   ; // ���������� ��� ������ �������
      ChildrenVisible := FFChildrenVisible.Value ; // ���������� ��� ����, ���� ���������� ������� �������
      Inactive        := FFInactive.Value        ; // ���������� ��� ����, ���� ���������� ������� �������

      trueEOF := ( RecordCount = RecNo ) ;
      try
         Edit ; // Edit � ������ �������� �������� Insert

         FFInactive.AsBoolean := FFInactive.AsBoolean or ( not FFChildrenVisible.IsNull and not FFChildrenVisible.AsBoolean ) ; // ���� � ���������� ������ ��� ������� ������ �� ��������� �������� ��� ������������ ������� �� ���������
         FFChildrenVisible.AsBoolean := true ; // ������ � ������ ����� (���)�������
//       LocalUpdate := true ;
         Post ;
//       LocalUpdate := false ;

         if trueEOF then
            Abort // ����� Abort �������� � finally
         else
            Next ;
      finally
//       LocalUpdate := false ;

         if trueEOF then Append ;
      end ;
   end ;

   inherited ;
end ;

procedure TSQLQuery.DoAfterInsert;
var DBG : TDBGrid ;
begin
   DBG := TDBGrid ( GetDataSetGrid ( nil , self ) ) ;
   DBGridEditing ( DBG ) ;

   if assigned ( FFParent ) then FFParent.Value := PKValue ;   // ������ ������� ������ ���������� �������
   PKValue := Null ;

   FFLevel.AsInteger := Level ;
   FFVisible.AsBoolean := true ;

   DBG.DBGInplaceRect ; // ������ ����� ���������� ���� 'Level'

   inherited ;
end ;

procedure TSQLQuery.DoBeforeDelete ;
begin
   if PKValue = Null then // �������� ������������
   begin
      if not FFChildrenVisible.IsNull then raise Exception.Create ( '������ ������� �������� �����' ) ;

      Level   := FFLevel.AsInteger ;
      PKValue := FFParent.Value     ; // ���������� ������!
   end ;

   inherited ;
end ;

procedure TSQLQuery.DoAfterDelete ;
begin
   if FFLevel.AsInteger < Level then
   begin
      if PKValue <> FFId.Value then Prior ; // ���� ����� ��������{��������� ������} � ��� ������� �� ������, �� Prior �� �����

      if FFLevel.AsInteger = Level - 1 then // ��������� � ������ ��� ������ ���� �������, ChildrenVisible ����� ��������
         try
//            LocalUpdate := true ;
            Edit ;
            FFChildrenVisible.Clear ;
            Post ;
         finally
//            LocalUpdate := false ;
         end ;
   end ;
   PKValue := Null ;

   inherited ;
end ;

procedure TSQLQuery.DoAfterEdit ;
var DBG : TDBGrid ;
begin
   DBG := TDBGrid ( GetDataSetGrid ( nil , self ) ) ;
   DBGridEditing ( DBG ) ;

   inherited ;
end ;

procedure TSQLQuery.DoAfterCancel ;
//ERRATA �� �������������� State=dsEdit, ������ dsInsert
var DBG : TDBGrid ;
begin
   if ( RecordCount > RecNo ) then // ������� ������ ��� dsBrowse
   begin
      Prior ; // ��� Update �� ������� �� ������������

      Edit ;
      FFChildrenVisible.Value := ChildrenVisible ; // ���������� ���������� ��������
      FFInactive.Value        := Inactive        ; // ���������� ���������� ��������
//      LocalUpdate := true ;
      Post ;
//      LocalUpdate := false ;
   end
   else
   begin
      DBG := TDBGrid ( GetDataSetGrid ( nil , self ) ) ;
      DBGridEditing ( DBG , false ) ;
   end ;

   inherited ;
end ;

procedure TSQLQuery.DoAfterPost ;
begin
   DBGridEditing ( TDBGrid ( GetDataSetGrid ( nil , self ) ) , false ) ;

   inherited ;
end ;

procedure TSQLQuery.InsertTree ( Ig , Parent : TID ; Caption , RelationAlias : string ; IsParent : boolean = true ) ;
var trueEOF : boolean ;
begin // ��� ������ ������, ���������� ��������� � BeforeInsert/AfterInsert
   if     ( RecordCount > 0 )
      and not IsParent
      and ( TDBGrid ( GetDataSetGrid ( nil , self ) ).Search ( nil , Parent ) <> 1 ) then // ��������� ����� � � ������ ������
   begin
      ShowMessage ( '������ ���������� ������' ) ;
      Exit ;
   end ;

   PKValue         := FFId.Value ;
   if RecordCount = 0 then Level := 0 else Level := FFLevel.AsInteger + 1 ;
   childrenVisible := FFChildrenVisible.Value ; // ��������� � �����, �.�. BeforeInsert ���������
   Inactive        := FFInactive.Value ; // ������ �������������� ������� ����� ��� �������, ������ �� ����������

   try
      trueEOF := ( RecordCount = RecNo ) ;

      if RecordCount > 0 then
      begin
         Edit ; // ��� ������� ����� ������(��� ���������� �������) ����� �� ��������� ������ Insert

         FFInactive.AsBoolean := FFInactive.AsBoolean or ( not FFChildrenVisible.IsNull and not FFChildrenVisible.AsBoolean ) ; // ���� � ���������� ������ ��� ������� ������ �� ��������� �������� ��� ������������ ������� �� ���������
         FFChildrenVisible.AsBoolean := true ; // ������ � ������ ����� (���)�������

//         LocalUpdate := true ;
         Post ;
//         LocalUpdate := false ;
      end ;

      if trueEOF then
         Append
      else
      begin
         Next ;
         Insert ;
      end ;

      FFId.Value    := Ig ;
//      FFParent.Value    := Parent ; // TDBGridTree.Search � TDBGridTree.MSQTreeAfterInsert �������� ��� ����
      FFCaption.AsString := Caption ; // Parent ����� ������������� �������� � AfterInsert
      if assigned ( FindField ( 'RelationAlias' ) ) then
         FieldByName ( 'RelationAlias' ).AsString := RelationAlias ; // ����� ��� ���������, ���� �����-������ ���������� �� ����

//      LocalUpdate := true ; // ��� ��� ������� � TDBGridTree.Search
      Post ;
   finally
//      LocalUpdate := false ;
   end ;

   inherited ;
end ;

end.
