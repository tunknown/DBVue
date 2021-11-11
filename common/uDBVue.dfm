object DDBVue: TDDBVue
  OldCreateOrder = False
  Left = 191
  Top = 125
  Height = 150
  Width = 215
  object QColumns: TMSQuery
    SQL.Strings = (
      ';with'#9'cte'#9'as'
      '('#9'select'
      #9#9'sc.id'
      #9#9',sc.name'
      #9#9',sc.colid'
      #9#9',t.Value'
      #9#9',t.Sequence'
      #9'from'
      #9#9'sysobjects'#9'so'
      #9#9'inner'#9'join'#9'syscolumns'#9'sc'#9'on'
      #9#9#9'sc.id='#9'so.id'
      #9#9'outer'#9'apply'#9'dbo.ToListFromString ( sc.name,'#9#39'|'#39','#9'0 )'#9't'
      #9'where'
      #9#9'so.name'#9'like'#9':ObjectAlias+'#9#39'|%'#39
      #9'union'#9'all'
      #9'select'
      #9#9'*'
      #9'from'
      #9#9'cte'
      #9'where'
      #9#9'id'#9'is'#9'null'#9')'
      'select'
      #9'c1.id'
      #9',Sequence='#9#9'c1.colid'
      #9',c1.name'
      #9',[code]='#9#9'nullif ( c1.Value,'#9#39#39' )'
      #9',[type]='#9#9'nullif ( c2.Value,'#9#39#39' )'
      #9',[width]='#9#9'nullif ( c3.Value,'#9#39#39' )'
      #9',[mask]='#9#9'nullif ( c4.Value,'#9#39#39' )'
      #9',[group]='#9#9'nullif ( c5.Value,'#9#39#39' )'
      #9',[lookup_object]='#9'nullif ( c6.Value,'#9#39#39' )'
      #9',[lookup_field]='#9'nullif ( c7.Value,'#9#39#39' )'
      #9',[caption]='#9#9'nullif ( c8.Value,'#9#39#39' )'
      'from'
      #9'cte'#9'c1'
      #9'left'#9'join'#9'cte'#9'c2'#9'on'
      #9#9'c2.id='#9#9'c1.id'
      #9'and'#9'c2.name='#9'c1.name'
      #9'and'#9'c2.Sequence='#9'2'
      #9'left'#9'join'#9'cte'#9'c3'#9'on'
      #9#9'c3.id='#9#9'c1.id'
      #9'and'#9'c3.name='#9'c1.name'
      #9'and'#9'c3.Sequence='#9'3'
      #9'left'#9'join'#9'cte'#9'c4'#9'on'
      #9#9'c4.id='#9#9'c1.id'
      #9'and'#9'c4.name='#9'c1.name'
      #9'and'#9'c4.Sequence='#9'4'
      #9'left'#9'join'#9'cte'#9'c5'#9'on'
      #9#9'c5.id='#9#9'c1.id'
      #9'and'#9'c5.name='#9'c1.name'
      #9'and'#9'c5.Sequence='#9'5'
      #9'left'#9'join'#9'cte'#9'c6'#9'on'
      #9#9'c6.id='#9#9'c1.id'
      #9'and'#9'c6.name='#9'c1.name'
      #9'and'#9'c6.Sequence='#9'6'
      #9'left'#9'join'#9'cte'#9'c7'#9'on'
      #9#9'c7.id='#9#9'c1.id'
      #9'and'#9'c7.name='#9'c1.name'
      #9'and'#9'c7.Sequence='#9'7'
      #9'left'#9'join'#9'cte'#9'c8'#9'on'
      #9#9'c8.id='#9#9'c1.id'
      #9'and'#9'c8.name='#9'c1.name'
      #9'and'#9'c8.Sequence='#9'8'
      'where'
      #9#9'c1.Sequence='#9'1'
      'order'#9'by'
      #9'c1.id'
      #9',c1.colid')
    Left = 40
    Top = 24
    ParamData = <
      item
        DataType = ftUnknown
        Name = 'ObjectAlias'
      end>
  end
end
