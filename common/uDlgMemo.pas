unit uDlgMemo;

interface

uses
   Windows, Controls, Forms, StdCtrls, Buttons, ExtCtrls, Classes , db , grids , dbgrids , SysUtils ;

type
   TDBGridHack = class ( TDBGrid ) ;
   TCustomEditHack = class ( TCustomEdit ) ;

  TFMemo = class(TForm)
    Memo1: TMemo;
    BBOK: TBitBtn;
    BBCancel: TBitBtn;

    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
  public
  end;

function GetMemoField ( F : TField ; var str : string ; Editor : TCustomEdit ) : boolean ;

implementation

{$R *.dfm}

uses
   XMLDoc,
   commonDS ;

function GetMemoField ( F : TField ; var str : string ; Editor : TCustomEdit ) : boolean ;
var s : string ; // дополнительное присваивание- плохо, но пришлось для упрощения
begin
   if MustEllipsis ( f ) <> meString then
   begin
      Result := false ;
      Exit ;
   end ;

   with TFMemo.Create ( nil ) do
      try
         Memo1.ReadOnly :=    ( assigned ( f      ) and not ( f.DataSet.State in [dsInsert , dsEdit] ) )
                           or ( assigned ( Editor ) and TCustomEditHack ( Editor ).ReadOnly ) ;
         BBOK.Enabled   := not Memo1.ReadOnly ;

         if     assigned ( Editor )
            and (    Editor.Modified
                  or not assigned ( f ) ) then
         begin
            s := Editor.Text ;
            Editor.Modified := false ; // ситуацию обрабатывам, поэтому поле в гриде больше не считать изменённым
         end
         else
            if assigned ( f ) then
               s := f.AsString
            else
               s := str ;

         if ( s[1] = '<' ) and ( pos ( '<html' , s ) = 0 ) then
            try
               Memo1.Text := FormatXMLData ( s ) ;
            except
               Memo1.Text := s ;
            end
         else
            Memo1.Text := s ; 

         Result := ( ShowModal = mrOK ) ;

         if Result then
            if assigned ( f ) then
            begin
               if ( f.DataSet.State in [dsInsert , dsEdit] ) and not F.ReadOnly then f.AsString := Memo1.Text ;
            end
            else
            begin
               str := Memo1.Text ;
               if assigned ( Editor ) and not TCustomEditHack ( Editor ).ReadOnly then
               begin
                  Editor.Text := str ;
                  Editor.Modified := false ; // поле в гриде больше не считать изменённым чтобы при повторном вызове не посчитать за новые данные
               end ;
            end ;
      finally
         Free ;
      end ;
end ;

procedure TFMemo.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   if     ( Key = VK_RETURN ) // по Ctrl+Enter подтверждать окно
      and ( ssCtrl in Shift )
      and BBOK.Enabled then
      BBOK.Click
   else
      if Key = VK_ESCAPE then BBCancel.Click ;
end;

end.
