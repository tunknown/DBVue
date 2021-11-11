object FMemo: TFMemo
  Left = 192
  Top = 103
  Width = 288
  Height = 352
  BorderStyle = bsSizeToolWin
  Caption = #1042#1074#1077#1076#1080#1090#1077' '#1090#1077#1082#1089#1090
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Shell Dlg'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poScreenCenter
  OnKeyDown = FormKeyDown
  DesignSize = (
    280
    325)
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 280
    Height = 283
    Align = alTop
    Anchors = [akLeft, akTop, akBottom]
    Ctl3D = False
    ParentCtl3D = False
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object BBOK: TBitBtn
    Left = 112
    Top = 292
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    TabOrder = 1
    Kind = bkOK
  end
  object BBCancel: TBitBtn
    Left = 196
    Top = 292
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = #1054#1090#1084#1077#1085#1072
    TabOrder = 2
    Kind = bkCancel
  end
end
