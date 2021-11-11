unit SplitterMy ;

interface

uses Classes , ExtCtrls ;

type
   TSplitter = class ( ExtCtrls.TSplitter )
      procedure SplitterClick(Sender: TObject);
   public
      IsMoving : boolean ; // достаточно бы одной переменной для всех сплиттеров приложения, т.к. они передвигаются строго по одному
      constructor Create(TheOwner: TComponent); override;

      procedure SplitterMouseMove(Sender: TObject; Shift: TShiftState; {%H-}X, {%H-}Y: Integer);
      property OnClick ;
      property OnMouseMove ;
   end ;

implementation

uses Controls ;

constructor TSplitter.Create(TheOwner: TComponent);
begin
   inherited Create ( TheOwner ) ;

   IsMoving := false ;
   OnClick := @SplitterClick ;
   OnMouseMove := @SplitterMouseMove ;
end ;

procedure TSplitter.SplitterClick(Sender: TObject);
var xy : integer ;
    pn : TPoint ;
    bMinimized : boolean ;
begin
   if not ( Sender is TSplitter ) then Exit ;

   if IsMoving then
      IsMoving := false
   else
   begin
      if ResizeAnchor in [akLeft , akRight] then
         bMinimized := ( ResizeControl.Width  <= 1 ) or ( GetOtherResizeControl.Width  <= 1 )
      else
         bMinimized := ( ResizeControl.Height <= 1 ) or ( GetOtherResizeControl.Height <= 1 ) ;

      if bMinimized then
      begin
         xy := MinSize ; // размер до скрытия возобновляем из MinSize
         MinSize := 1 ;
      end
      else
      begin
         xy := 1 ;
         MinSize := GetSplitterPosition ; // в MinSize сохраняем размер до скрытия
      end ;

      if ResizeAnchor in [akLeft , akRight] then pn := TPoint.Create ( xy , 0 ) else pn := TPoint.Create ( 0 , xy ) ;
      StopSplitterMove ( pn ) ;
      if 1 < xy then SetSplitterPosition ( xy ) ;
   end ;
end ;

procedure TSplitter.SplitterMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
   if ( ssLeft in Shift ) and ( Sender is TSplitter ) then IsMoving := true ;
end;

end.
