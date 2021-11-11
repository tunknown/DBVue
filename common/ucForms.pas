unit ucForms;

interface

uses
  Windows , Classes, forms , DB, dbgrids {, DBAccess}, StdCtrls,SysUtils{,variants} , Controls
  , common ;

const
   IIDTFForm = '{09D89544-74AB-4AED-861F-69DDD77FCFA5}' ;

type
   ITFForm = interface[IIDTFForm]
      procedure SetParameters ( DM : TDataModule ; Alias : string ; Ig : TID ; Desc : string ; Selection : boolean ; Value : TParams ) ; stdcall ;

      procedure GetIgDesc     ( var Ig : TID ; var Desc : string ) ; stdcall ;

      function  Search        : integer ; stdcall ;
   end;

   TDataModuleClass = class of TDataModule ;

   TCustomFormHack = class ( TCustomForm ) ;

{
   function GetObject ( FC : TFormClass ; DMC : TDataModuleClass ; Alias : string ;                        var Ig : TID ; var Desc : string ; Editor : TCustomEdit ; NeedShow : boolean = false ; Params : TParams = nil ) : boolean ;
   function GetObject ( FC : TFormClass ; DMC : TDataModuleClass ; Alias : string ; FIg , FDesc : TField ;                                    Editor : TCustomEdit ; NeedShow : boolean = false ; Params : TParams = nil ) : boolean ;
}
   function GetObject ( FC : TFormClass ; DMC : TDataModuleClass ; Alias : string ; FIg , FDesc : TField ; var Ig : TID ; var Desc : string ; Editor : TCustomEdit ; NeedShow : boolean = false ; Params : TParams = nil ) : boolean ;

implementation

function GetObject ( FC : TFormClass ; DMC : TDataModuleClass ; Alias : string ; FIg , FDesc : TField ; var Ig : TID ; var Desc : string ; Editor : TCustomEdit ; NeedShow : boolean = false ; Params : TParams = nil ) : boolean ;
var ITFForm1 : ITFForm ;
    DM : TDataModule ;
    IFC : boolean ;
    s : string ;
    FM : TForm ;
//ERRATA ��� ��������� ������� ������� ���� � �������� ��� �������, ��� ��������� ���� ������ �� ������� ����, �� ������ ��� ������ ������� Editor.Modified
begin
   Result := false ;

   if assigned ( Editor ) and Editor.Modified then
   begin
      Ig   := Null ;
      Desc := Editor.Text ;
      Editor.Modified := false ; // �������� �����������, ������� ���� � ����� ������ �� ������� ���������

      if Desc = '' then
      begin
         if assigned ( FIg ) then
         begin
            FIg.Clear ;
            FDesc.Clear ;
         end ;
         if not NeedShow then Exit ;
      end ;
   end
   else
      if assigned ( FIg ) then
         if FIg.IsNull then
         begin
            Ig   := Null ;
            Desc := '' ;
         end
         else
         begin
            Ig   := FIg.Value ;
            Desc := FDesc.AsString ;
         end ;

   if assigned ( DMC ) then {DM := DMC.Create ( nil )}Application.CreateForm ( DMC , DM ) else DM := nil ;

   try
      Application.CreateForm ( FC , FM ) ; //FM := FC.Create ( nil ) ; // ��� CreateForm ����� �� ����� � ������ �����������

      with TCustomFormHack ( FM ) do
         try
            s := PostfixateComponent ( FM ) ; // ��������������� ����� �������� ����������� �����, ����� ��� ��������� �������� ����������� ������ ���� ����� � ������������ ������ � � ��� ����� ����������� ����������� ����� � ����������� � ����������� ���� ������, ���� ������� ���������
            if assigned ( DM ) then PostfixateComponent ( DM , s ) ; // ��������������� ����� �������� ����������� �����, ����� ��� ��������� �������� ����������� ������ ���� ���������� � ������������ ������ � � ���� ����� ����������� ����������� ����� � ����������� � ����������� �����������

            IFC := ( QueryInterface ( StringToGUID ( IIDTFForm ) , ITFForm1 ) = S_OK ) ;
            if IFC then
            begin
               ITFForm1.SetParameters ( DM , Alias , Ig , Desc , not assigned ( FIg ) or ( assigned ( FIg.DataSet ) and ( FIg.DataSet.State in [dsInsert , dsEdit] ) ) , Params ) ; // �������������� Selection:boolean �� �����������, ���� �� ������ ����
               NeedShow := ( ITFForm1.Search <> 1 ){��� ������, ����� ����� ���������} or NeedShow or GUIDNotEmpty ( Ig ) ;
            end
            else
               NeedShow := true ; // ���� ����� �� ����� ������, �� � ����� ������ ��������

            Result := ( not NeedShow{��� ������ �����} or ( ShowModal = mrOK ) ) and IFC ;

            if IFC then
            begin
               if Result then
                  ITFForm1.GetIgDesc ( Ig , Desc )
               else
               begin
                  Ig := Null ;
                  Desc := '' ;
               end ;

               if     assigned ( FIg )
                  and ( FIg.DataSet.State in [dsInsert , dsEdit] )
                  and not FIg.ReadOnly then
               begin
                  FIg.Value   := Ig ;
                  FDesc.Value := StringToNull ( Desc ) ;
               end ;
            end ;
         finally
            ITFForm1 := nil ; // ����������� �� ����������� ��������������� �����
            {Free}Release ;               // Release ������ ������, �.�. ������ ��������� DM.Free � ��� �������� ����� ��������� � ��������� ������� AV
            Application.ProcessMessages ; // ������ ����� Release ������?
         end ;
   finally
      if assigned ( DM ) then DM.Free ;
   end ;
end ;

end.
