unit commonCTRL ;
// ТОЛЬКО ПРОЦЕДУРЫ ОБРАЩЕНИЯ К ДБ-КОНТРОЛАМ

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

function GetDateTimePickerForFieldInternal ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;

function GetDateTimePickerForField ( F : TField ; var dt : TDateTime ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;
function GetDateTimePickerForField ( F : TField ; Editor : TCustomEdit ; DefaultDate : TDateTime ; ModeDefaultDate : integer = 0 ) : boolean ; overload ;

function GetDataSetNavigator ( Cmp : TComponent ; DS : TDataSet ) : TDBNavigator ;
procedure DBNavigatorPopup ( Sender : TDBNavigator ; PM : TPopupMenu ) ;

procedure LabelToRect           ( Column : TColumn ; Rect : TRect ; Lbl : TLabel ; Shadowing : boolean ) ;

procedure DBGColWidthsChanged ( DBG : TDBGrid ) ;
procedure DBGridEditing ( DBG : TDBGrid ; Editing : boolean = true ) ;

function GetParentRoot ( St : TControl ; CClass : TClass ; const CName : TComponentName = ' ' ) : TControl ;
function FindComponentEx ( Root : TComponent ; CClass : TClass ; const CName : TComponentName ) : TComponent ;


implementation

uses
   Windows , DateUtils , Messages , SysUtils , Dialogs , Variants , ComCtrls , Graphics , Forms , StrUtils , {$IFDEF FPC}datetimepicker ,{$ENDIF}
   common , commonDS ;

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
                  dt := trunc ( DefaultDate ) ; //убираем время из даты
            end ;

         DateTime := CombineDateAndTime ( dt , 0 ) ;

         Top    := Rect.Top    + Editor.Top ;  // здесь нужно учитывать, на каком контроле лежит TDateTimePicker
         Left   := Rect.Left   + Editor.Left ;
         Width  := Rect.Right  - Rect.Left ;
         Height := Rect.Bottom - Rect.Top ;

         OnDropDown := @(TDumbDTP.OnDropDown) ;

         SendMessage ( Handle , WM_SYSKEYDOWN , VK_DOWN , 0 ) ;

         while DroppedDown do
            Application.ProcessMessages ;

         Result := true ; // неизвестно, как проверить, что календарь был закрыт выбором, а не отменой

         if ( f.DataSet.State in dsEditModes ) and not f.ReadOnly then f.AsDateTime := trunc ( DateTime ) ; // если в поле есть время, то нельзя использовать этот метод
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
   with TDBNavigatorHack ( Sender ).Buttons[nbInsert] , ClientToScreen ( classes.Point ( Left , Top ) ) do
      PM.Popup ( X , Y + Height ) ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
procedure DBGColWidthsChanged ( DBG : TDBGrid ) ;
var i , SavLock : integer ;
begin
{$IFNDEF FPC}
   with TCustomDBGridHack ( DBG ) do
   begin
      SavLock := UpdateLock ; // из-за того, что он не 0 ColWidthsChanged не работает
      try
         for i := 0 to SavLock - 1 do
            EndUpdate ;

         ColWidthsChanged ; // DIRTY HACK для того, чтобы колонки отразили изменение видимости полей
      finally
         for i := 0 to SavLock - 1 do
            BeginUpdate ;
      end ;
   end ;
{$ENDIF}
end ;

procedure DBGridEditing ( DBG : TDBGrid ; Editing : boolean = true ) ;
begin // активация или создание InplaceEditor
   if not assigned ( DBG ) then Exit ;

   with TDBGridHack ( DBG ) do
      if Editing then
      begin
         Options := Options - [dgRowSelect] ;
         Options := Options + [dgEditing , dgAlwaysShowEditor] ;

{$IFNDEF FPC}
         if not assigned ( InplaceEditor ) then ShowEditor ; // чтобы здесь окончательно создался InplaceEditor
{$ENDIF}
      end
      else
      begin
         Options := Options - [dgEditing , dgAlwaysShowEditor] ;
         Options := Options + [dgRowSelect] ;
      end ;
end ;
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

function GetParentRoot ( St : TControl ; CClass : TClass ; const CName : TComponentName = ' ' ) : TControl ;
begin
   Result := St.Parent ;
   while assigned ( Result ) and ( not ( Result is CClass ) or ( ( Result.Name <> CName ) and ( CName <> ' '{space for finding without name} ) ) ) do
      Result := Result.Parent ;
end ;

function FindComponentEx ( Root : TComponent ; CClass : TClass ; const CName : TComponentName ) : TComponent ;
var i : integer ;
begin
   for i := 0 to Root.ComponentCount - 1 do
   begin
      Result := Root.Components[i] ;
      if ( Result is CClass ) and ( ( CName = ' '{space for finding without name} ) or ( CompareText ( Result.Name , CName ) = 0 ) ) then
         exit
      else
      begin
         Result := FindComponentEx ( Result , CClass , CName ) ;
         if assigned ( Result ) then exit ;
      end ;
   end ;
   Result := nil ;
end ;

end.
