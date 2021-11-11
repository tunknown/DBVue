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

      procedure RefreshMasterDetail ( SLMasters : TStringList{��������� ������ �� Detail} ) ;
   end ;

implementation

uses DB , SQLDB , SysUtils , Controls , Forms , StrUtils , variants
   , commonCTRL , commonDS
   , uDM;

procedure TDBGrid.GetSBVisibility(out HsbVisible, VsbVisible: boolean);
begin // ���� ����� ������� � �������� ������ ������ �����, �� ������������ ������ ��������� �� ����������
   inherited GetSBVisibility ( HsbVisible , VsbVisible ) ;

   if    not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet )
      or ( DataSource.DataSet.RecordCount <= VisibleRowCount ) then VsbVisible := false ;
end ;
//�������� �� �� ��� ��������������� �����

procedure TDBGrid.UpdateActive ;
begin // ���������� ��� ��������� ������� ������ � ����������
   inherited ;

   if //or not Focused // �� ���������, �.�. ��������� ������� ���� �������� ��� �����������
         not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet ) then Exit ;

   DoMasterDetail ;
end ;

procedure TDBGrid.Invalidate ;
begin // ���������� ��� multiselect, �� �� ��� ��������� ������� ������ ��� ���������
   inherited ;

   if    not ( dgMultiSelect in Options ) // ������ ������������������, �.�. ���������� ����� �����
      or not Focused{������ ��������}
      or not assigned ( Datalink )
      or not assigned ( DataSource )
      or not assigned ( DataSource.DataSet ) then Exit ;

   DoMasterDetail ;
end ;

procedure RefreshMasterDetailAll ( Root : TControl ; SLMasters : TStringList{��������� ������ �� Detail} ) ;
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
begin // TDataSet.AfterScroll, TDataSource.OnDataChange �� �������, �.�. ���������� �� ���������� � SelectedRows; ���������, ��� ������ ������� ����� ����������� �����; ?OnTimer
   Dlm := ',' ;
   with TDataSource ( DataSource ) , DataSet do
      try
         Cls := GetQueryInfo ( TSQLQuery ( DataSet ) ).Cls ;

         for i := 0 to FieldCount - 1 do
         begin
            Field := Fields[i] ;
            if ( Field.KeyFields <> '' ) or ( ( GetFieldInfo ( Field ).Method = 'K' ) and ( GetQueryInfo ( self ).Method[1] in ['V' , 'B'] ) ) then // ������� �������������� ����� Master ���� ��� ���������� Detail �����, ���������� �������
            begin
               sVal := Field.AsString ;
               if sVal = '' then sVal := 'null' ; // ��� ���������� ������ � ���� �����������, � Master-Detail ��������
               sav := Field.KeyFields ;

               if ( dgMultiSelect in Options ) and ( SelectedRows.Count <> 0 ) then
                  if SelectedRows.CurrentRowSelected then
                  begin
                     if pos ( Dlm + sVal + Dlm , Dlm + Field.KeyFields + Dlm ) = 0 then
                     begin
                        s := Trim ( Field.KeyFields ) ;
                        if s <> '' then s := s + Dlm ;
                        Field.KeyFields := s + sVal // ��������� ��� ����, ����� ����������� ������
                     end ;
                  end
                  else
                  begin
                     s := StringReplace ( Dlm + Field.KeyFields + Dlm , Dlm + sVal + Dlm , Dlm , [] ) ;
                     SetLength ( s , Length ( s ) - 1 ) ;
                     Field.KeyFields := StuffString ( s , 1 , 1 , '' ) ;
                  end
               else
                  Field.KeyFields := sVal ; // �� ��������� '' ����� ���������� Master-Detail

               if sav <> Field.KeyFields then
               begin
                  if not assigned ( SLMasters ) then SLMasters := TStringList.Create ;
                  SLMasters.Add ( Cls + '=' + GetFieldInfo ( Field ).Attribute ) ;
               end;
            end ;
         end ;

         if assigned ( SLMasters ) then RefreshMasterDetailAll ( GetParentRoot ( self , TForm ) , SLMasters ) ; // todo ����� ��������� �� ���, � ������ ����������
      finally
         if assigned ( SLMasters ) then SLMasters.Free ;
      end ;
end ;

procedure TDBGrid.RefreshMasterDetail ( SLMasters : TStringList{��������� ������ �� Detail} ) ;
var DSM : TDataSet ;
    s : string = '' ;
    i , j : integer ;
    AttrMaster , sClassMaster , sClassDetail , sCompare , sParam : string ;
    FDetail , FMaster : TField ;
// todo ������ ��������� ������� � ����� where ��� ������������� � ����������� �����������
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
               AttrMaster := Trim ( FieldByName ( 'AttributeRef' ).AsString )  // todo ������ Trim
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
                        if AttrMaster = Trim ( FieldByName ( 'Attribute' ).AsString ) then  // todo ������ Trim
                        begin
                           if FMaster.KeyFields <> '' then
                           begin
                              s := TSQLQuery ( DataSet ).SQL.Text ;
                              sCompare := 'in'                    ; // ������� ������� MasterDetail
                              sParam   := ' ' + FMaster.KeyFields ; // ������� ������� MasterDetail
                              DM1.SQLSet ( TSQLQuery ( DataSet ).SQL , FDetail.FieldName , sCompare , sParam , string ( nil^ ) , boolean ( nil^ ) ) ;
                              if s <> TSQLQuery ( DataSet ).SQL.Text then QInit ( DataSet ) ; // ����������� �� ���������� ������������ Master-Detail
                           end ;
                           break ;
                        end;
               end ;
         end ;
      end ;
   end ;
end ;

end.
