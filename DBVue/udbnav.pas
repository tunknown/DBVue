unit uDBNav;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, DBCtrls, Buttons, ExtCtrls , DB ;

type

   TDBNavigator = class ( DBCtrls.TDBNavigator )
   protected
     FOnEditingChanged : TDataSetNotifyEvent ;
     procedure EditingChanged; override ;
   public
     property OnEditingChanged: TDataSetNotifyEvent read FOnEditingChanged write FOnEditingChanged;
   end;

  { TRDBNavigator }

  TRDBNavigator = class(TFrame)
    PDone: TPanel;
    SBDone: TSpeedButton;
    DBNSingle: TDBNavigator;
    procedure FrameResize(Sender: TObject);
    procedure SBDoneClick(Sender: TObject);
  private
    function GetSelectable : boolean ;
    procedure SetSelectable ( Value : boolean ) ;
  public
     property IsSelectable : boolean read GetSelectable write SetSelectable ;

     procedure Enabler ( DataSet : TDataSet ) ;
  end;

implementation

uses commonCTRL ;

{$R *.lfm}

{ TRDBNavigator }

procedure TDBNavigator.EditingChanged ;
var DS : TDataSet = nil ;
begin
   inherited ;

   if assigned ( DataSource ) then DS := DataSource.DataSet ;
   if assigned ( FOnEditingChanged ) then OnEditingChanged ( DS ) ;
end ;

function TRDBNavigator.GetSelectable : boolean ;
begin
   Result := PDone.Visible ;
end ;

procedure TRDBNavigator.Enabler ( DataSet : TDataSet ) ;
var b : boolean ;
begin
   if IsSelectable then
   begin
      b := assigned ( DataSet ) ;
      if b then b := ( DataSet.State = dsBrowse ) ;
      with PDone do if b then BringToFront else SendToBack ;
   end ;
end ;

procedure TRDBNavigator.SetSelectable ( Value : boolean ) ;
begin
   PDone.Visible := Value ;
end ;

procedure TRDBNavigator.FrameResize(Sender: TObject);
begin
   with DBNSingle do
   begin
      PDone.Left  := Buttons[nbPost].Left ;
      PDone.Width := Buttons[nbPost].Width + Buttons[nbCancel].Width ;

      OnEditingChanged := @Enabler ;
   end ;
end ;

procedure TRDBNavigator.SBDoneClick(Sender: TObject);
var F : TForm ;
begin
   F := TForm ( GetParentRoot ( nil , TForm ) ) ;
   if assigned ( F ) then F.ModalResult := mrOK ;
end ;

end.

