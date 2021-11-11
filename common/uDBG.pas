unit uDBG ;
// ���������� ����� � ���������

interface

uses Classes , DB , dbgrids , Types , Grids , StdCtrls , Controls , Contnrs , DBCtrls , Menus ;

const
   LocatorParamName = 'Ig' ;
   LocatorFieldName = 'Ig' ;

type
   TCustomDBGridHack = class ( TCustomDBGrid ) ;
   TDBNavigatorHack = class ( TDBNavigator ) ;

   TDumbDTP = class ( TObject )
      class procedure OnDropDown ( Sender : TObject ) ;
   end ;

   TDBGridHack = class ( TDBGrid ) ;

   TCustomGridHack = class ( TCustomGrid ) ;

   TDataSourceHack = class ( TDataSource )
      property DataLinks ;
   end ;

   TDBGrid = class ( DBGrids.TDBGrid )
      procedure DoExit           ; override ;
      procedure KeyDown          ( var Key : Word ; Shift : TShiftState ) ; override ;
      procedure EditButtonClick  ; override ;
      procedure DrawColumnCell   ( const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState); override ;
   end ;

   TDBNavigator = class ( DBCtrls.TDBNavigator )
      procedure BtnClick       ( Button : TNavigateBtn ) ; override ;
   end ;

   TDataSource = class ( DB.TDataSource )
      procedure StateChange      ;
      procedure DataChange       ( Field : TField ) ;

      procedure DSStateChange      ( AC : TWinControl ) ;
      procedure DSDataChange       ( AC : TWinControl ; Field : TField ) ;
   end ;


function GetDateTimePickerForFieldInternal ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;

function GetDateTimePickerForField ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;
function GetDateTimePickerForField ( F : TField ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;

function GetDataSetNavigator ( Cmp : TComponent ; DS : TDataSet ) : TDBNavigator ;
procedure DBNavigatorPopup ( Sender : TDBNavigator ; PM : TPopupMenu ) ;

procedure LabelToRect           ( Column : TColumn ; Rect : TRect ; Lbl : TLabel ; Shadowing : boolean ) ;

procedure DBGColWidthsChanged ( DBG : TDBGrid ) ;
procedure DBGridEditing ( DBG : TDBGrid ; Editing : boolean = true ) ;

function GetFirstVisibleField ( DBG : TDBGrid ; ShowReadOnly : boolean = false ) : TField ;


implementation

uses
   Windows , DateUtils , Messages , SysUtils , Dialogs , Variants , ComCtrls , Graphics , Forms , StrUtils ,
   MSAccess ,
   common , commonDS, uDlgMemo , uDBGTree;

function GetFirstVisibleField ( DBG : TDBGrid ; ShowReadOnly : boolean = false ) : TField ;
var i : integer ;
begin
   Result := nil ;
   if not assigned ( DBG ) or ( DBG.Columns.Count = 0 ) then Exit ;

   with DBG.Columns do
      for i := 0 to Count - 1 do
         if assigned ( Items[i].Field ) and Items[i].Visible and ( not Items[i].ReadOnly or ShowReadOnly ) then // ��������� �� ����, � �������, �.�. ��� ��������� �������� �����
         begin
            Result := Items[i].Field ;
            Exit ;
         end ;
end ;

class procedure TDumbDTP.OnDropDown ( Sender : TObject ) ;
begin
   if not ( Sender is TDateTimePicker ) then Exit ;

   windows.SetFocus ( SendMessage ( TDateTimePicker ( Sender ).Handle , $1000 + $8{DTM_GETCALMONTH} , 0 , 0 ) ) ;
end ;

function GetDateTimePickerForField ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ;
begin
   if MustEllipsis ( f ) <> meDateTime then
   begin
      Result := false ;
      Exit ;
   end ;

   Result := GetDateTimePickerForFieldInternal ( F , dt , Editor , DefaultDate , ModeDefaultDate ) ;
end ;

function GetDateTimePickerForField ( F : TField ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;
var dt : TDateTime ;
begin
   Result := GetDateTimePickerForField ( F , dt , Editor , DefaultDate , ModeDefaultDate ) ;
end ;

function GetDateTimePickerForFieldInternal ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ;
var Rect : TRect ;
begin
   if not assigned ( Editor ) then
   begin
      Result := false ;
      Exit ;
   end ;

   with TDateTimePicker.Create ( nil ) do
      try
         Rect := Editor.ClientRect ;
         Parent := Editor.Parent ;

         SendToBack ;

         if not f.IsNull then
            dt := trunc ( f.AsDateTime )
         else
            case ModeDefaultDate of
               1 :
                  dt := StartOfTheMonth ( DefaultDate ) ;
               2 :
                  dt := EndOfTheMonth ( DefaultDate ) ;
               else
                  dt := trunc ( DefaultDate ) ; //������� ����� �� ����
            end ;

         DateTime := CombineDateAndTime ( dt , 0 ) ;

         Top    := Rect.Top    + Editor.Top ;  // ����� ����� ���������, �� ����� �������� ����� TDateTimePicker
         Left   := Rect.Left   + Editor.Left ;
         Width  := Rect.Right  - Rect.Left ;
         Height := Rect.Bottom - Rect.Top ;

         OnDropDown := TDumbDTP.OnDropDown ;

         SendMessage ( Handle , WM_SYSKEYDOWN , VK_DOWN , 0 ) ;

         while DroppedDown do
            Application.ProcessMessages ;

         Result := true ; // ����������, ��� ���������, ��� ��������� ��� ������ �������, � �� �������

         if ( f.DataSet.State in dsEditModes ) and not f.ReadOnly then f.AsDateTime := trunc ( DateTime ) ; // ���� � ���� ���� �����, �� ������ ������������ ���� �����
      finally
         Free ;
      end ;
end ;

function GetDataSetNavigator ( Cmp : TComponent ; DS : TDataSet ) : TDBNavigator ;
var i : integer ;
    CurCmp : TComponent ;
begin
   if not assigned ( Cmp ) then Cmp := Screen{Application} ;

   for i := 0 to Cmp.ComponentCount - 1 do
   begin
      CurCmp := Cmp.Components[i] ;
      if CurCmp is TDBNavigator then
      begin
         Result := TDBNavigator ( CurCmp ) ;
         if not assigned ( Result.DataSource ) or ( Result.DataSource.DataSet <> DS ) then Result := nil ;
      end
      else
         Result := GetDataSetNavigator ( CurCmp , DS ) ;

      if assigned ( Result ) then Exit ;
   end ;
   Result := nil ;
end ;

procedure DBNavigatorPopup ( Sender : TDBNavigator ; PM : TPopupMenu ) ;
begin
   with TDBNavigatorHack ( Sender ).Buttons[nbInsert] , ClientToScreen ( Point ( Left , Top ) ) do
      PM.Popup ( X , Y + Height ) ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TDataSource.StateChange ;
//var DS : TDataSource ;
begin
//   if not ( Sender is TDataSource ) then exit ;
//   DS := TDataSource ( Sender ) ;

   if State <> dsInactive then DSStateChange ( nil ) ; //��������, ��� �������� ����� �� ������������ //Screen.ActiveControl ������������ ������, �.�. ����� ����� ������ �� ������ ��������

   inherited ;
end ;

procedure DBGColWidthsChanged ( DBG : TDBGrid ) ;
var i , SavLock : integer ;
begin
   with TCustomDBGridHack ( DBG ) do
   begin
      SavLock := UpdateLock ; // ��-�� ����, ��� �� �� 0 ColWidthsChanged �� ��������
      try
         for i := 0 to SavLock - 1 do
            EndUpdate ;

         ColWidthsChanged ; // DIRTY HACK ��� ����, ����� ������� �������� ��������� ��������� �����
      finally
         for i := 0 to SavLock - 1 do
            BeginUpdate ;
      end ;
   end ;
end ;

procedure DBGridEditing ( DBG : TDBGrid ; Editing : boolean = true ) ;
begin // ��������� ��� �������� InplaceEditor
   if not assigned ( DBG ) then Exit ;

   with TDBGridHack ( DBG ) do
      if Editing then
      begin
         Options := Options - [dgRowSelect] ;
         Options := Options + [dgEditing , dgAlwaysShowEditor] ;

         if not assigned ( InplaceEditor ) then ShowEditor ; // ����� ����� ������������ �������� InplaceEditor
      end
      else
      begin
         Options := Options - [dgEditing , dgAlwaysShowEditor] ;
         Options := Options + [dgRowSelect] ;
      end ;
end ;

procedure TDataSource.DSStateChange ( AC{���� ����� �������� ActiveControl} : TWinControl ) ;

   procedure Focusing ( WC : TWinControl ) ;
   var F : TCustomForm ;
   begin
      F := GetParentForm ( WC ) ;
      if WC.CanFocus and F.Visible then
         WC.SetFocus
      else
         F.ActiveControl := WC ;
   end ;

var DBG : TDBGrid ;
    em : boolean ;
begin
   if not ( AC is TDBGrid ) then AC := GetDataSourceGrid ( self , nil ) ;

   if not assigned ( AC ) then Exit ;

   DBG := TDBGrid ( AC ) ;

   with TDBGridHack ( DBG ) , Columns do
   begin
      if     {( DS.DataSet.State = dsBrowse )
         and }assigned ( InplaceEditor ) then
      begin
         em := EditorMode ;
         EditorMode := false ;
         InplaceEditor.Text := '' ; // ����� ����� �� ������� � �� �� ���������� ��������������
         EditorMode := em ;
      end ;

      if self.State in dsEditModes then // ��� ��������� �������������� ���������� ������ �� ������������� ����, ��� ������� ���������� �� ������ ���� ��������������
      begin
         DBGridEditing ( DBG ) ;

         if ( self.State = dsInsert ) or Items[SelectedIndex].ReadOnly{��� dsEdit} then
         begin
            SelectedIndex := 0 ; // ����� ���������� ���� �� ������
            SelectedField := GetFirstVisibleField ( DBG ) ;
         end ;

         Focusing ( DBG ) ; // ��� ����� ����� �� InplaceEditor �� ���������
         Focusing ( TDBGridHack ( DBG ).InplaceEditor ) ;
      end
      else
      begin
//         Options := Options + [dgMultiSelect] ;

         if VisibleColCount <= Col then SelectedIndex := 0 ;

         Options := Options - [{dgEditing , }dgAlwaysShowEditor] ;
         HideEditor ; // ����� ������ �������������� � ��������� ��� ���������
         if assigned ( OnColEnter ) then OnColEnter ( DBG{Sender} ) ; // ���������� ��� �����-������
      end ;
   end ;
end ;

procedure TDataSource.DataChange(Field: TField);
//var DS : TDataSource ;
begin
//   if not ( Sender is TDataSource ) then Exit ;
//   DS := TDataSource ( Sender ) ;

   DSDataChange ( nil , Field ) ; //Screen.ActiveControl ������������ ������, �.�. ����� ����� ������ �� ������ ��������

   inherited ;
end;

procedure TDataSource.DSDataChange( AC : TWinControl ; Field: TField);
var DBG : TDBGrid ;
    ODCSave : TDataChangeEvent ;
begin
   if MustEllipsis ( Field ) <> meObject then Exit ;

   if AC is TDBGrid then
      DBG := TDBGrid ( AC )
   else
      DBG := TDBGrid ( GetDataSourceGrid ( self ) ) ;

   if not assigned ( DBG ) then Exit ;

   ODCSave := OnDataChange ;
   with DBG do
      if     assigned ( OnEditButtonClick )
         and ( DataSource.State in dsEditModes )
         and (    ( Field.NewValue <> Field.OldValue )
               and{or} (     assigned ( TDBGridHack ( DBG ).InplaceEditor )           // ������ ���� ������� ����� �������������� ���� ���� ��� ��� �����
                    and TDBGridHack ( DBG ).InplaceEditor.Modified ) ) then      // ����� ������ ���� ����� �������
         try
            OnDataChange := nil ;

            //EventHolderComponentParamNew ( DBG , 'FieldDataDialog.NeedShow' , false ) ;

            try
               OnEditButtonClick ( DBG ) ; // ������ ���� ������ DBG, � Field ����� �������� �� DBG.SelectedField
            finally
               //EventHolderComponentParamFree ( DBG , 'FieldDataDialog.NeedShow' ) ;
            end ;
         finally
            OnDataChange := ODCSave ;
         end ;
end;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure LabelToRect ( Column : TColumn ; Rect : TRect ; Lbl : TLabel ; Shadowing : boolean ) ;
var Size : TSize ;
    RectLeft , RectTop : integer ;
begin
   with TDBGrid ( Column.Grid ).Canvas do
   begin
      FillRect ( Rect ) ;

      if not assigned ( Lbl ) then Exit ;

      Font := Lbl.Font ;

      SetBkMode ( Handle , TRANSPARENT ) ;
      Font.Color := clBlack ;
      Font.Style := [fsBold] ;

      Size := TextExtent ( Lbl.Caption ) ;
      RectLeft := Rect.Left + ( Rect.Right - Rect.Left - Size.CX ) div 2 + 2 ;
      RectTop  := Rect.Top  + ( Rect.Bottom - Rect.Top - Size.CY ) div 2 - 2 ;

      if Shadowing then
         ExtTextOut ( Handle ,
                      RectLeft ,
                      RectTop ,
                      0 ,
                      @Rect ,
                      PChar ( Lbl.Caption ) ,
                      Length ( Lbl.Caption ) ,
                      nil ) ;

      Font := Lbl.Font ;
      ExtTextOut ( Handle ,
                   RectLeft ,
                   RectTop ,
                   0 ,
                   @Rect ,
                   PChar ( Lbl.Caption ) ,
                   Length ( Lbl.Caption ) ,
                   nil ) ;
   end ;
end;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TDBGrid.DrawColumnCell(const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var DS : TDataSet ;
    DBG : TDBGrid ;
    r : TRect ;
begin
   DBG := TDBGrid ( Column.Grid ) ;
   DS := Column.Grid.DataSource.DataSet ;

   with TCustomGridHack ( DBG ) do
      r := CellRect ( Col , Row ) ;

   if ( DS.State in dsEditModes ) and ( r.Top = Rect.Top ) and ( r.Bottom = Rect.Bottom ) then
      with DBG do
      begin
         Canvas.Brush.Color := clInfoBk ;
         Canvas.Font.Color  := clInfoText ;
         DefaultDrawColumnCell ( Rect , DataCol , Column , State ) ;
      end ;

   inherited ;
end ;

procedure TDBGrid.KeyDown ( var Key : Word ; Shift : TShiftState ) ;
var ClearKey : boolean ;
begin
   ClearKey := false ;

//   if ( Sender is TDBGrid ) then // Exit ������ ������, �.�. TDBGrid_OnKeyDown ������ ����������
      case Key of
         VK_RETURN : // �� Ctrl+Enter �������� Post
            if     ( ssCtrl in Shift )
               and assigned ( DataSource )
               and ( DataSource.State in dsEditModes ) then // =assigned ( DataSet )
            begin
               DataSource.DataSet.Post ;
               ClearKey := true ;
            end ;
         VK_DOWN : // �� Alt+Down �������� ���� ������
            if ssAlt in Shift then
            begin
               //EventHolderComponentParamNew ( TDBGrid ( Sender ) , 'FieldDataDialog.NeedShow' , true ) ;

               try
                  EditButtonClick ;
               finally
                  //EventHolderComponentParamFree ( TDBGrid ( Sender ) , 'FieldDataDialog.NeedShow' ) ;
               end ;

               ClearKey := true ;
            end ;
         VK_LEFT ,
         VK_RIGHT : // � �.�. � ��� TDBGridTree
            if dgRowSelect in Options then ClearKey := true ;
      end ;

   try
      inherited ;
   finally
      if ClearKey then Key := 0 ; // ����� �� ���������� ��������� ������� ������
   end ;
end ;

procedure TDBGrid.EditButtonClick;
var F : TField ;
    Key : word ;
    s : string ;
    dt : TDateTime ;
begin
   if GetAsyncKeyState ( VK_CONTROL ) and GetAsyncKeyState ( VK_RETURN ) and $8000 = $8000 then // �� Ctrl+Enter �� �������� ���� ������
   begin
      Key := VK_RETURN ;
      KeyDown ( Key , [ssCtrl] ) ;
      Exit ;
   end ;

   F := SelectedField ;

{   with F do
      if     assigned ( OnChange      )
         and assigned ( LookupDataSet )
         and ( KeyFields         <> '' )
         and ( LookupKeyFields   <> '' )
         and ( LookupResultField <> '' ) then
         try
            Tag := integer ( TDBGridHack ( Sender ).InplaceEditor ) ; // ���� InplaceEditor ��� �� ��������, �� ������ �� ���������
//���������� �� push,pop;;;��� TField.OnChange ������ ���������� �������������� � ��������� ���� �������� ������ �� Lookup?

            OnChange ( F ) ; // ������� ����������� ���������� ���� ���� ������ ��������������
         finally
            Tag := 0 ;
         end
      else}
   if assigned ( F ) then
      case MustEllipsis ( F ) of
         meDateTime :
            GetDateTimePickerForField ( F , dt , InplaceEditor , now , 0 ) ;
         meString :
            GetMemoField ( F , s , InplaceEditor ) ;
      end ;

   inherited ;
end ;

procedure TDBGrid.DoExit ;
begin
   if     assigned ( DataSource ) // ������ ���� �� ������ ��� � design time, �� ����������� ����� ��������
      and ( DataSource.State in dsEditModes ) then {��������, dgCancelOnExit} // �� TDBLookupEdit ����� ��������, �.�. ��� �������� TEdit //=assigned ( DataSet )
      with DataSource.DataSet do
         if Modified then
            case Application.MessageBox ( '�� ������� ��������� �������� ������?' , '��������' , MB_YESNOCANCEL or MB_ICONWARNING ) of
               IDYES    : Post ;
               IDNO     : Cancel ;
               IDCANCEL : SetFocus ;
            end
         else
            Cancel ;

//   if ( ( TDBGrid ( Sender ).Columns.Count = 1 ) and ( TDBGrid ( Sender ).Columns[0].ButtonStyle = cbsEllipsis ) ) then Exit ; // �� TDBLookupEdit ����� ��������, �.�. ��� �������� TEdit

   inherited ;
end;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TDBNavigator.BtnClick ( Button : TNavigateBtn ) ;
begin
   if     ( Button = nbCancel )
      //and ( Sender is TDBNavigator )
      and assigned ( {TDBNavigator ( Sender ).}DataSource )
      and assigned ( {TDBNavigator ( Sender ).}DataSource.DataSet )
      and {TDBNavigator ( Sender ).}DataSource.DataSet.Modified
      and ( Application.MessageBox ( '�������� ��������� ��������� ?' , '' , MB_ICONWARNING or MB_YESNO ) = IDNO ) then Abort ;

   inherited ;   
end ;

end.
