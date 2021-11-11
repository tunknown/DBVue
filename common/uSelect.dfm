object FSelector: TFSelector
  Left = 192
  Top = 103
  Width = 240
  Height = 320
  ActiveControl = DBLLB
  BorderStyle = bsSizeToolWin
  Color = clBtnFace
  Constraints.MinHeight = 320
  Constraints.MinWidth = 240
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Shell Dlg'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    232
    293)
  PixelsPerInch = 96
  TextHeight = 13
  object DBLLB: TDBGrid
    Left = 0
    Top = 28
    Width = 232
    Height = 221
    Anchors = [akLeft, akTop, akRight, akBottom]
    Ctl3D = False
    DataSource = DSList
    Options = [dgEditing, dgTitles, dgColumnResize, dgColLines, dgRowLines, dgTabs, dgConfirmDelete, dgCancelOnExit]
    ParentCtl3D = False
    TabOrder = 0
    TitleFont.Charset = DEFAULT_CHARSET
    TitleFont.Color = clWindowText
    TitleFont.Height = -11
    TitleFont.Name = 'MS Shell Dlg'
    TitleFont.Style = []
    OnDblClick = DBLLBDblClick
  end
  object BBOK: TBitBtn
    Left = 80
    Top = 260
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    TabOrder = 1
    Kind = bkOK
  end
  object BBCancel: TBitBtn
    Left = 164
    Top = 260
    Width = 63
    Height = 25
    Anchors = [akRight, akBottom]
    Cancel = True
    Caption = #1054#1090#1084#1077#1085#1072
    ModalResult = 2
    TabOrder = 2
    Glyph.Data = {
      DE010000424DDE01000000000000760000002800000024000000120000000100
      0400000000006801000000000000000000001000000000000000000000000000
      80000080000000808000800000008000800080800000C0C0C000808080000000
      FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00333333333333
      333333333333333333333333000033338833333333333333333F333333333333
      0000333911833333983333333388F333333F3333000033391118333911833333
      38F38F333F88F33300003339111183911118333338F338F3F8338F3300003333
      911118111118333338F3338F833338F3000033333911111111833333338F3338
      3333F8330000333333911111183333333338F333333F83330000333333311111
      8333333333338F3333383333000033333339111183333333333338F333833333
      00003333339111118333333333333833338F3333000033333911181118333333
      33338333338F333300003333911183911183333333383338F338F33300003333
      9118333911183333338F33838F338F33000033333913333391113333338FF833
      38F338F300003333333333333919333333388333338FFF830000333333333333
      3333333333333333333888330000333333333333333333333333333333333333
      0000}
    NumGlyphs = 2
    Spacing = 0
  end
  object CBAll: TCheckBox
    Left = 4
    Top = 264
    Width = 93
    Height = 17
    Anchors = [akLeft, akBottom]
    Caption = #1055#1086#1082#1072#1079#1072#1090#1100' '#1074#1089#1077
    TabOrder = 3
    Visible = False
    OnClick = CBAllClick
  end
  object BNew: TButton
    Left = 164
    Top = 4
    Width = 63
    Height = 19
    Anchors = [akTop, akRight]
    Caption = #1057#1086#1079#1076#1072#1085#1080#1077
    TabOrder = 4
    OnClick = BNewClick
  end
  object Edit12: TEdit
    Left = 0
    Top = 4
    Width = 73
    Height = 19
    Anchors = [akLeft, akTop, akRight]
    Ctl3D = False
    ParentCtl3D = False
    TabOrder = 5
    OnChange = Edit12Change
  end
  object Button2: TButton
    Left = 80
    Top = 4
    Width = 75
    Height = 19
    Anchors = [akTop, akRight]
    Caption = #1055#1086#1080#1089#1082
    TabOrder = 6
    OnClick = Button2Click
  end
  object DSList: TDataSource
    DataSet = MSQuery
    Left = 108
    Top = 52
  end
  object MSQuery: TMSQuery
    Left = 60
    Top = 52
  end
end
