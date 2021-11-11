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
//ERRATA при выбранном объекте очищаем поли и вызываем эту функцию, она открывает окно только со второго раза, на первый раз только очистит Editor.Modified
begin
   Result := false ;

   if assigned ( Editor ) and Editor.Modified then
   begin
      Ig   := Null ;
      Desc := Editor.Text ;
      Editor.Modified := false ; // ситуацию обрабатывам, поэтому поле в гриде больше не считать изменённым

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
      Application.CreateForm ( FC , FM ) ; //FM := FC.Create ( nil ) ; // без CreateForm формы не будет в списке компонентов

      with TCustomFormHack ( FM ) do
         try
            s := PostfixateComponent ( FM ) ; // переименовываем после создания ссылающейся формы, чтобы при следующем создании существовал только одна форма с оригинальным именем и к ней могла прицепиться создаваемая форма с прописанной в дизайнтайме этой формой, буде таковая обрящется
            if assigned ( DM ) then PostfixateComponent ( DM , s ) ; // переименовываем после создания ссылающейся формы, чтобы при следующем создании существовал только один датамодуль с оригинальным именем и к нему могла прицепиться создаваемая форма с прописанным в дизайнтайме датамодулем

            IFC := ( QueryInterface ( StringToGUID ( IIDTFForm ) , ITFForm1 ) = S_OK ) ;
            if IFC then
            begin
               ITFForm1.SetParameters ( DM , Alias , Ig , Desc , not assigned ( FIg ) or ( assigned ( FIg.DataSet ) and ( FIg.DataSet.State in [dsInsert , dsEdit] ) ) , Params ) ; // автовычисление Selection:boolean не срабатывает, если не поданы поля
               NeedShow := ( ITFForm1.Search <> 1 ){идёт первым, чтобы поиск отработал} or NeedShow or GUIDNotEmpty ( Ig ) ;
            end
            else
               NeedShow := true ; // если форма не умеет искать, то её можно только показать

            Result := ( not NeedShow{без показа формы} or ( ShowModal = mrOK ) ) and IFC ;

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
            ITFForm1 := nil ; // обязательно до уничтожения отнаследованной формы
            {Free}Release ;               // Release нельзя писать, т.к. раньше произойдёт DM.Free и при закрытии формы обращение к датасетам вызовет AV
            Application.ProcessMessages ; // теперь можно Release писать?
         end ;
   finally
      if assigned ( DM ) then DM.Free ;
   end ;
end ;

end.
