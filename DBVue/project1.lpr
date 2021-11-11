program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms
  ,Classes
  ,Variants
  ,datetimectrls
  ,common in '..\common\common.pas'
  ,commonCTRL in '..\common\commonCTRL.pas'
  ,commonDS in '..\common\commonDS.pas'
  ,ucForms in '..\common\ucForms.pas'
  ,SplitterMy in '..\common\SplitterMy.pas'
  ,FUIFast in '..\common\FUIFast.pas'
  ,uDBGTree in '..\common\uDBGTree.pas', uDBGTree1, DBGridsMy
  , uDM, Unit1, uGridData, uFltSngl, uDBGMD, uDBNav;

{$R *.res}

var Ig : TID ;
    Desc : string ;
    DM : TDataModule ;

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;

  Ig := null ;
  Desc := '' ;
  Application.CreateForm(TDM, DM);
  uDM.DM1 := TDM ( DM ) ;

  GetObject ( TForm1 , nil , 'Payments' , nil , nil , Ig , Desc , nil , true , nil ) ; //Application.CreateForm(TForm1, Form1);
  Exit ;
  //Application.Run;
end.
//debug dcu: add all paths fcl-db/*.*/*.* to project options/compiler paths/other files units and hide files from \lazarus\fpc\3.2.0\units\i386-win32\fcl-db
