unit DBGridsMy ;

interface

uses classes , DBGrids ;

type
   TDBGrid = class ( DBGrids.TDBGrid )
   protected
      procedure GetSBVisibility(out HsbVisible, VsbVisible: boolean); override ;
      procedure UpdateActive ; override ;
   public
      procedure Invalidate ; override ;

      procedure DoMasterDetail ;

      procedure RefreshMasterDetail ( SLMasters : TStringList{обновлять только их Detail} ) ;
   end ;

implementation

uses DB , SQLDB , SysUtils , Controls , Forms , StrUtils , variants
   , commonCTRL , commonDS
   , uDM;

procedure TDBGrid.GetSBVisibility(out HsbVisible, VsbVisible: boolean);
begin // если число записей в датасете меньше высоты грида, то вертикальную полосу прокрутки не отображать
   inherited GetSBVisibility ( HsbVisible , VsbVisible ) ;

   if    not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet )
      or ( DataSource.DataSet.RecordCount <= VisibleRowCount ) then VsbVisible := false ;
end ;
//добавить то же для горизонтального грида

procedure TDBGrid.UpdateActive ;
begin // вызывается при изменении текущей записи с прокруткой
   inherited ;

   if //or not Focused // не проверять, т.к. прокрутка колесом мыши работает без фокусировки
         not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet ) then Exit ;

   DoMasterDetail ;
end ;

procedure TDBGrid.Invalidate ;
begin // вызывается при multiselect, но не при изменении текущей записи без прокрутки
   inherited ;

   if    not ( dgMultiSelect in Options ) // беречь производительность, т.к. вызывается очень часто
      or not Focused{тяжёлая нагрузка}
      or not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet ) then Exit ;

   DoMasterDetail ;
end ;

procedure RefreshMasterDetailAll ( Root : TControl ; SLMasters : TStringList{обновлять только их Detail} ) ;
var i : integer ;
    Cnt : TControl ;
    Cmp : TComponent ;
begin
   //if not assigned ( Root ) then Root := GetParentRoot ( Application , TForm ) ;
   for i := 0 to Root.ComponentCount - 1 do
   begin
      Cmp := Root.Components[i] ;
      if Cmp.InheritsFrom ( TControl ) then
      begin
         Cnt := TControl ( Cmp ) ;
         if Cnt is TDBGrid{TRDataGrid} then
            {TRDataGrid}TDBGrid ( Cnt ).RefreshMasterDetail ( SLMasters )
         else
            RefreshMasterDetailAll ( Cnt , SLMasters ) ;
      end;
   end ;
end ;

procedure TDBGrid.DoMasterDetail ;
var i : integer ;
    SLMasters : TStringList = nil ;
    Cls : string = '' ;
    s , sVal : string ;
    Field : TField ;
    Dlm : char ;
    sav : string ;
begin // TDataSet.AfterScroll, TDataSource.OnDataChange не годятся, т.к. происходят до добавления в SelectedRows; учитываем, что другие способы могут дублировать вызов; ?OnTimer
   Dlm := ',' ;
   with TDataSource ( DataSource ) , DataSet do
      try
         Cls := GetQueryInfo ( TSQLQuery ( DataSet ) ).Cls ;

         for i := 0 to FieldCount - 1 do
         begin
            Field := Fields[i] ;
            if ( Field.KeyFields <> '' ) or ( ( GetFieldInfo ( Field ).Method = 'K' ) and ( GetQueryInfo ( self ).Method[1] in ['V' , 'B'] ) ) then // признак используемости этого Master поля для фильтрации Detail грида, достаточно пробела
            begin
               sVal := Field.AsString ;
               if sVal = '' then sVal := 'null' ; // при добавлении записи её поля незаполнены, а Master-Detail работает
               sav := Field.KeyFields ;

               if ( dgMultiSelect in Options ) and ( SelectedRows.Count <> 0 ) then
                  if SelectedRows.CurrentRowSelected then
                  begin
                     if pos ( Dlm + sVal + Dlm , Dlm + Field.KeyFields + Dlm ) = 0 then
                     begin
                        s := Trim ( Field.KeyFields ) ;
                        if s <> '' then s := s + Dlm ;
                        Field.KeyFields := s + sVal // проверять тип поля, чтобы квотировать строки
                     end ;
                  end
                  else
                  begin
                     s := StringReplace ( Dlm + Field.KeyFields + Dlm , Dlm + sVal + Dlm , Dlm , [] ) ;
                     SetLength ( s , Length ( s ) - 1 ) ;
                     Field.KeyFields := StuffString ( s , 1 , 1 , '' ) ;
                  end
               else
                  Field.KeyFields := sVal ; // не допускать '' иначе отключится Master-Detail

               if sav <> Field.KeyFields then
               begin
                  if not assigned ( SLMasters ) then SLMasters := TStringList.Create ;
                  SLMasters.Add ( Cls + '=' + GetFieldInfo ( Field ).Attribute ) ;
               end;
            end ;
         end ;

         if assigned ( SLMasters ) then RefreshMasterDetailAll ( GetParentRoot ( self , TForm ) , SLMasters ) ; // todo нужно обновлять не все, а только подчинённые
      finally
         if assigned ( SLMasters ) then SLMasters.Free ;
      end ;
end ;

procedure TDBGrid.RefreshMasterDetail ( SLMasters : TStringList{обновлять только их Detail} ) ;
var DSM : TDataSet ;
    s : string = '' ;
    i , j : integer ;
    AttrMaster , sClassMaster , sClassDetail , sCompare , sParam : string ;
    FDetail , FMaster : TField ;
// todo должен вставлять условия в конец where для совместимости с однопольной фильтрацией
begin
   if not assigned ( SLMasters ) then Exit ;

   with DataSource , DataSet do
   begin
      sClassDetail := GetQueryInfo ( TSQLQuery ( DataSet ) ).Cls ;

      for i := 0 to FieldCount - 1 do
      begin
         FDetail := Fields[i] ;
         with DM1.QAttributesAll do
            if Locate ( 'Class;ColumnName;Method' , VarArrayOf ( [{%H-}sClassDetail , FDetail{%H-}.FieldName , {%H-}'M'] ) , [loCaseInsensitive] ) then
               AttrMaster := Trim ( FieldByName ( 'AttributeRef' ).AsString )  // todo убрать Trim
            else
               continue ;

         DSM := FDetail.LookupDataSet ;

         if assigned ( DSM ) then
         begin
            sClassMaster := GetQueryInfo ( TSQLQuery ( DSM ) ).Cls ;
            if SLMasters.IndexOfName ( sClassMaster ) <> -1 then
               for j := 0 to DSM.FieldCount - 1 do
               begin
                  FMaster := DSM.Fields[j] ;

                  with DM1.QAttributesAll do
                     if Locate ( 'Class;ColumnName' , VarArrayOf ( [{%H-}sClassMaster , FMaster{%H-}.FieldName] ) , [loCaseInsensitive] ) then
                        if AttrMaster = Trim ( FieldByName ( 'Attribute' ).AsString ) then  // todo убрать Trim
                        begin
                           if FMaster.KeyFields <> '' then
                           begin
                              s := TSQLQuery ( DataSet ).SQL.Text ;
                              sCompare := 'in'                    ; // признак фильтра MasterDetail
                              sParam   := ' ' + FMaster.KeyFields ; // признак фильтра MasterDetail
                              DM1.SQLSet ( TSQLQuery ( DataSet ).SQL , FDetail.FieldName , sCompare , sParam , string ( nil^ ) , boolean ( nil^ ) ) ;
                              if s <> TSQLQuery ( DataSet ).SQL.Text then QInit ( DataSet ) ; // кеширование от повторного срабатывания Master-Detail
                           end ;
                           break ;
                        end;
               end ;
         end ;
      end ;
   end ;
end ;

end.
