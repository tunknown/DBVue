unit uDS ;
// КОМПОНЕНТЫ ДАТАСЕТА

interface

uses Classes , DB , dbgrids , Types , Grids , StdCtrls , Controls , Contnrs , DBCtrls , Menus , MSAccess ;

const
   LocatorParamName = 'Ig' ;
   LocatorFieldName = 'Ig' ;

type
   TDBGridHack = class ( TDBGrid ) ;
   TFieldHack = class ( TField ) ;

   TMSQuery = class ( MSAccess.TMSQuery )
      procedure DoBeforeRefresh      ; override ;// нужно как-то вставить в EventHolderComponentListAdd, но без пересечения с DBGTree
   end ;

   TStringField = class(DB.TStringField)
      constructor Create (AOwner: TComponent) ; override ;
      procedure OnChange1           (Sender: TField) ;
      procedure OnSetText1          (Sender: TField; const Text: string) ;
   end ;


implementation

uses
   Windows , DateUtils , Messages , SysUtils , Dialogs , Variants , ComCtrls , Graphics , Forms , StrUtils ,
   common , commonDS, uSelect, uDBGTree;

////////////////////////////////////////////////////////////////////////////////////////////////////
procedure TMSQuery.DoBeforeRefresh ;
begin
   if     ( State in dsEditModes )
      and Modified then
         case Application.MessageBox ( 'Вы желаете сохранить введённые данные?' , 'Внимание' , MB_YESNOCANCEL or MB_ICONWARNING ) of
            //IDYES    : Break ;
            IDNO     : Cancel ;
            IDCANCEL : Abort ;
         end ;

   inherited ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
constructor TStringField.Create(AOwner: TComponent);
var FNE : TFieldNotifyEvent ;
    FSTE : TFieldSetTextEvent ;
begin
   inherited ;

   FNE := OnChange1 ;
   OnChange := FNE ;

   FSTE := OnSetText1 ;
   OnSetText := FSTE ;
end ;

procedure TStringField.OnChange1(Sender: TField);
begin
      if ( Tag <> 0 ) and ( TObject ( Tag ) is TInplaceEdit ) then
         GetSelection ( TMSQuery ( LookupDataSet ) , nil , DataSet.FieldByName ( KeyFields ) , self , '' , '' , TInplaceEdit ( Tag ) , not ( DataSet.State in dsEditModes ) or ( TMSQuery ( LookupDataSet ).SQLInsert.Text = '' ) ) ;
end ;

procedure TStringField.OnSetText1(Sender: TField; const Text: string);
begin
   if     ( DataType = ftDateTime )
      and ( DataSet.State in dsEditModes )
      and ( Text[1] = ' ' )
      and ( Text[2] = ' ' ) then
      Clear
   else
      Value := Text ; // без этого при ручном вводе введённый текст не сохраняется
end ;

end.
