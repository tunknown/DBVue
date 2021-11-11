unit uDBLEdit;

interface

uses
   Windows , Classes , Forms , Controls , Grids , DBGrids , db ,
   DBGridsMy{������ ����� DBGrids} ;

type
   TCustomGridAccess = class ( TCustomGrid ) ;
   TWinControlAccess = class ( TWinControl ) ;
   TCustomDBGridAccess = class ( TCustomDBGrid ) ;

   TDBLookupEdit = class ( TFrame )
      DBG : TDBGrid ;
      procedure FrameResize ( Sender : TObject ) ;
      procedure DBGKeyDown  ( Sender : TObject ; var Key : Word ; Shift : TShiftState ) ;
      procedure DBGMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
   private
   public
   end ;

implementation

uses StdCtrls ;

{$R *.lfm}

procedure TDBLookupEdit.FrameResize ( Sender : TObject ) ;
begin
   DBG.Columns[0].Width := DBG.Width ; // ������� ������ �������� ��� ������ �����

   if assigned ( TCustomGridAccess ( DBG ).InplaceEditor ) then Exit ; // ������ ����������� ������ ������ ���

   DBG.handle ; // ShowEditor ���������� HandleNeeded � � 0 �� ��������
   {$IFNDEF FPC}
   TCustomGridAccess ( DBG ).ShowEditor ;
   {$ENDIF}
end ;

procedure ToInplaceEditor ( DBG : TDBGrid ) ;
begin
   with TCustomDBGridAccess ( DBG ) do
      if assigned ( InplaceEditor ) and ( DataSource.State in dsEditModes ) and ( Columns[SelectedIndex].Field.Text <> TCustomEdit ( InplaceEditor ).Text ) then Columns[SelectedIndex].Field.Text := TCustomEdit ( InplaceEditor ).Text ; // ����� �������� InplaceEditor.Text �� �������� � ������� � ��� ��������� ������� ����� ������������ ��������� ���������, ��������� � ����������/����. InplaceEditor.OnChange ���� �� �������� ��� ���������
end ;

procedure TDBLookupEdit.DBGKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   if    ( Key in [VK_UP , VK_PRIOR , VK_DOWN , VK_NEXT , VK_INSERT , VK_ESCAPE] )
      or ( ( ssCtrl in Shift ) and ( Key in [VK_LEFT , VK_RIGHT , VK_HOME , VK_END , VK_DELETE] ) ) then
      Key := 0 ; // �������� ��������� ��������� ������� ��������(������� ����� ������)

   ToInplaceEditor ( DBG ) ;
end ;

procedure TDBLookupEdit.DBGMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
   ToInplaceEditor ( DBG ) ; // ERROR ����������� � ���������� ��� �� �������, � ��� ������ ������ ����+Paste ��������
end;

end.
