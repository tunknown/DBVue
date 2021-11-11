unit uDM;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, SQLDB , DBGrids , DB ;

const cSelect  = 'select'   ;
      cFrom    = 'from'     ;
      cWhere   = 'where'    ;
      cOrderBy = 'order by' ;
      cAsc     = 'asc'      ;
      cDesc    = 'desc'     ;
      cCompare = '=|<>|<|<=|>|>=|like|not like' ;

type
   TQueryInfo = record
      Cls : string ;
      Sequence : Byte ;
      Method : string[1] ;
      Caption : string ;
   end ;

   TFieldInfo = record
      Attribute : string ;
      Method : string[1] ;
      Width : string[3] ;
      Mask : string ;
      Group : string ;
      ClassRef : string ;
      AttributeRef : string ;
      Caption : string ;
   end ;

   { TDM }
   TSQLSelect = record
      FieldName : UnicodeString ;
      Start     : integer ; // for replacing or deleting
      Length    : integer ;
   end ;
   ASQLSelect = array of TSQLSelect ;

   TSQLFrom = record
      ObjectName : UnicodeString ;
      Schema     : UnicodeString ; // nullable
      DataBase   : UnicodeString ; // nullable
      Server     : UnicodeString ; // nullable
      Start      : integer ; // for size counting to add "where"
      Length     : integer ;
   end ;
   ASQLFrom = array of TSQLFrom ;

   TSQLWhere = record
      FieldName  : UnicodeString ;
      Comparison : string[16] ;
      Quote      : string[1] ;
      Parameter  : UnicodeString ; // todo null support
      Start : integer ; // for replacing or deleting
      Length : integer ;
   end ;
   ASQLWhere = array of TSQLWhere ;

   TSQLOrderBy = record
      FieldName : UnicodeString ;
      Order     : string[4] ;
      Start     : integer ; // for replacing or deleting
      Length    : integer ;
   end ;
   ASQLOrderBy = array of TSQLOrderBy ;

   TDM = class(TDataModule)
      QActions: TSQLQuery;
      QAttributesAll: TSQLQuery;
      QClassRoot: TSQLQuery;
      QAttributesRef: TSQLQuery;
      QParameters: TSQLQuery;
      QSQLize: TSQLQuery;
      SQLConnector: TSQLConnector;
      SQLTransaction: TSQLTransaction;
      QClasses: TSQLQuery;
      QMasterDetail: TSQLQuery;

     procedure DataModuleCreate   ( Sender : TObject ) ;
   private

   public
     function  GetCacheFilter     ( F : TField ) : TSQLQuery ;
     procedure CacheFilter        ( DSE : TDataSet ) ;

     function  SQLParse           ( SQL : TStrings ; var ASelect : ASQLSelect ; var AFrom : ASQLFrom ; var AWhere : ASQLWhere ; var AOrderBy : ASQLOrderBy ) : boolean ; // true=support minifilter
     procedure SQLSet             ( SQL : TStrings ; const Fld : string ; var Oper , Param , OrderBy : string ; var Visibility : boolean ) ;

     procedure GetFilterOrder     ( SQL : TStrings ; const FieldName : string ; var bFilter : boolean ; var sOrderBy : string ) ;
   end;

function GetObjectName ( SQL  : TStrings  ) : string ; overload ;
function GetObjectName ( SQLQ : TSQLQuery ) : string ; overload ;
function GetObjectName ( DBG  : TDBGrid   ) : string ; overload ;

function GetQueryInfo ( SQL : TStrings ) : TQueryInfo ; overload ;
function GetQueryInfo ( DS  : TDataSet ) : TQueryInfo ; overload ;
function GetQueryInfo ( DBG : TDBGrid  ) : TQueryInfo ; overload ;

function GetFieldInfo ( F : TField ) : TFieldInfo ; overload ;
function GetFieldInfo ( F : string ) : TFieldInfo ; overload ;

function GetClassFromStr ( s : string ) : string ; deprecated ;

var DM1 : TDM ;

implementation

uses TypInfo , StrUtils , Variants , Forms , dialogs , regexpr
     , commonDS ;

{$R *.lfm}

procedure TDM.DataModuleCreate(Sender: TObject);
begin
   QInit ( QAttributesAll ) ;
   QInit ( QActions ) ;
end ;

function GetQueryInfo ( SQL : TStrings ) : TQueryInfo ; overload ;
var AFrom : ASQLFrom = nil ;
    REx : TRegExpr ;
begin
   SetLength ( AFrom , 1 ) ;
   DM1.SQLParse ( SQL , ASQLSelect ( nil^ ) , AFrom , ASQLWhere ( nil^ ) , ASQLOrderBy ( nil^ ) ) ;

   if ( AFrom = nil ) or ( AFrom[0].ObjectName = '' ) then Exit ;
   REx := TRegExpr.Create ( '^([^|]+)[|]([VBSTRZWEP])(?:[|](\d)(?:[|]([^|]+))?)?$' ) ;
   try
      if REx.Exec ( AFrom[0].ObjectName ) then
      begin
         Result.Cls      := REx.Match[1] ;
         Result.Method   := REx.Match[2] ;
         Result.Sequence := StrToInt ( REx.Match[3] ) ;
         Result.Caption  := REx.Match[4] ;
      end ;
   finally
      REx.Free ;
      AFrom := nil ;
   end ;
end ;

function GetQueryInfo ( DS : TDataSet ) : TQueryInfo ; overload ;
begin
   Result := GetQueryInfo ( TSQLQuery ( DS ) .SQL ) ;
end ;

function GetQueryInfo ( DBG : TDBGrid  ) : TQueryInfo ; overload ;
begin
   Result := GetQueryInfo ( TSQLQuery ( DBG.DataSource.DataSet ).SQL ) ;
end ;

function GetObjectName ( SQL : TStrings ) : string ;
var AFrom : ASQLFrom = nil ;
begin
   SetLength ( AFrom , 1 ) ;
   try
      DM1.SQLParse ( SQL , ASQLSelect ( nil^ ) , AFrom , ASQLWhere ( nil^ ) , ASQLOrderBy ( nil^ ) ) ;
      Result := AFrom[0].ObjectName ;
   finally
      AFrom := nil ;
   end ;
end ;

function GetObjectName ( SQLQ : TSQLQuery ) : string ;
begin
   Result := GetObjectName ( SQLQ.SQL ) ;
end;

function GetObjectName ( DBG : TDBGrid ) : string ;
var SQL : TStringList ;
begin
   SQL := TStringList ( GetObjectProp ( DBG.DataSource.DataSet , 'SQL' , TStringList ) ) ;
   if SQL = nil then Exit ;

   Result := GetObjectName ( SQL ) ;
end ;

function GetFieldInfo ( F : string ) : TFieldInfo ; overload ;
var REx : TRegExpr ;
begin
   REx := TRegExpr.Create ( '^([^|]+)\|([ KNMFLJYG]+)(?:\|(\d{0,3}%?)(?:\|([^|]+)?(?:\|([^|]+)?(?:\|([^|]+)?)?(?:\|([^|]+)?)?(?:\|([^|]+)?)?)?)?)?$' ) ; // todo в "[ KNMFLJYG]+" убрать "+"
   try
      if REx.Exec ( F ) then
      begin
         Result.Attribute    := REx.Match[1] ;
         Result.Method       := REx.Match[2] ;
         Result.Width        := REx.Match[3] ;
         Result.Mask         := REx.Match[4] ;
         Result.Group        := REx.Match[5] ;
         Result.ClassRef     := REx.Match[6] ;
         Result.AttributeRef := REx.Match[7] ;
         Result.Caption      := REx.Match[8] ;
      end ;
   finally
      REx.Free ;
   end ;
end ;

function GetFieldInfo ( F : TField ) : TFieldInfo ;
begin
   Result := GetFieldInfo ( F.FieldName ) ;
end ;

function GetClassFromStr ( s : string ) : string ;
var iFinish : integer ;
begin
   iFinish := Pos ( '|' , s ) ;
   if 0 = iFinish then
      Result := ''
   else
      Result := copy ( s , 1 , iFinish ) ;
end;

function TDM.GetCacheFilter ( F : TField ) : TSQLQuery ;
var ssql : string ;
    j : integer ;
    Cmp : TComponent ;
begin
   Result := nil ;

   if not ( F.DataType in [ftBoolean] ) then
   begin // todo или грузить вместо lookup полей сами справочники? грузить исходный объект грида или фильтр по нему?
      ssql := 'select distinct Caption=' + F.FieldName.QuotedString ( '"' ) + 'from"dbo".' + GetObjectName ( TSQLQuery ( F.DataSet ) ).QuotedString ( '"' ) + 'order by 1' ; // DB.ExtractFieldName trim tailing spaces from field names
      for j := ComponentCount - 1 downto 0 do // вначале идут неподходящие нам designtime компоненты
      begin
         Cmp := Components[j] ;
         if ( Cmp is TSQLQuery ) and ( CompareByte ( Cmp.Name , 'Cache' , Length ( 'Cache' ) ) = 0 ) and ( TSQLQuery ( Cmp ).SQL.Text = ssql ) then Result := TSQLQuery ( Cmp ) ;

         if assigned ( Result ) then break ;
      end ;

      if not assigned ( Result ) then
      begin
         Result := TSQLQuery.Create ( self ) ;

         with Result do // todo OnTimer/OnIdle обновлять кеш?
         begin
            Name := 'Cache' + IntToStr ( self.ComponentCount ) ; // компоненты не удаляются- такое имя будет уникальным
            DataBase := SQLConnector ;
            Transaction := SQLTransaction ;
            PacketRecords := -1 ;
            SQL.Text := ssql ;
            ReadOnly := true ;
            UsePrimaryKeyAsKey := false ; // todo сделать отдельный модуль, чтобы убрать UsePrimaryKeyAsKey=true по умолчанию и лишний запрос с сервера
            Open ;
         end ;
      end ;
   end ;
end;

procedure TDM.CacheFilter ( DSE : TDataSet ) ;
var i : integer ;
begin
   for i := 0 to DSE.FieldCount - 1 do
      GetCacheFilter ( DSE.Fields[i] ) ;
end ;

procedure TDM.SQLSet ( SQL : TStrings ; const Fld : string ; var Oper , Param , OrderBy : string ; var Visibility : boolean ) ;
// если параметр передан пустым, то отключаем, если не передан, то не затрагиваем
var iReplLen , iStart , i : integer ;
    sFilter , sParam , sOrderBy : string ;
    ASelect : ASQLSelect = nil ;
    AFrom : ASQLFrom = nil ;
    AWhere : ASQLWhere = nil ;
    AOrderBy : ASQLOrderBy = nil ;
    bsav , IsMasterDetail , bWhere , bOrderBy : boolean ;
begin // todo добавить поддержку group by
   SetLength ( ASelect  , 1 ) ;
   SetLength ( AFrom    , 1 ) ;
   SetLength ( AWhere   , 1 ) ;
   SetLength ( AOrderBy , 1 ) ;
   try
      if not SQLParse ( SQL , ASelect , AFrom , AWhere , AOrderBy ) then Exit ;

      // вставляем/убираем тексты начиная с конца, иначе все .Start съедут
      if assigned ( @OrderBy ) then
      begin
         if OrderBy <> '' then
         begin
            sOrderBy := Fld.QuotedString ( '"' ) + OrderBy ;

            if Length ( AOrderBy ) = 0 then
               try
                  bsav := SQL.TrailingLineBreak ;
                  SQL.TrailingLineBreak := false ;
                  iStart := Length ( SQL.Text ) ; // считаем, что там всегда будет только одна строка без добавленного CRLF в конце
                  iReplLen := 0 ;
                  sOrderBy := cOrderBy + sOrderBy ;
               finally
                  SQL.TrailingLineBreak := bsav ;
               end
            else
            begin
               iStart := 0 ;
               bOrderBy := false ;

               for i := 0 to Length ( AOrderBy ) - 1 do
               begin
                  bOrderBy := ( AOrderBy[i].FieldName = Fld ) ;
                  if bOrderBy then
                  begin
                     if AOrderBy[i].Order <> OrderBy then
                     begin
                        iReplLen := AOrderBy[i].Length ;
                        iStart := AOrderBy[i].Start ;
                     end ;
                     break ;
                  end ;
               end ;

               if not bOrderBy then
               begin
                  iStart := AOrderBy[0].Start ;
                  iReplLen := 0 ;
               end ;

               if iReplLen = 0 then sOrderBy := sOrderBy + ',' ; // к последней сортировке не добавлять
            end ;
         end
         else
         begin
            iStart := 0 ;

            for i := 0 to Length ( AOrderBy ) - 1 do
               if AOrderBy[i].FieldName = Fld then
               begin
                  iStart := AOrderBy[i].Start ;
                  iReplLen := AOrderBy[i].Length ;

                  if Length ( AOrderBy ) = 1 then
                  begin
                     iStart := iStart - Length ( cOrderBy ) ;
                     iReplLen := iReplLen + Length ( cOrderBy ) ;
                  end ;

                  if iStart <> 0 then sOrderBy := '' ;
                  break ;
               end ;
         end ;

         if iStart <> 0 then SQL.Text := StuffString ( SQL.Text , iStart + 1 , iReplLen , sOrderBy ) ;
      end ;

      if assigned ( @Oper ) and assigned ( @Param ) then // снятие неустановленного фильтра не должно вызывать ошибку
      begin
         iReplLen := 0 ;
         IsMasterDetail := ( GetFieldInfo ( Fld ).Method = 'M' ) and ( Oper = 'in' ) and ( Param[1] = ' ' ) ; // начало параметра с ' ' признак Master-Detail
         if IsMasterDetail then sParam := '(' + Param + ')' else sParam := Param.QuotedString ;

         if Oper = '' then
            sFilter := ''
         else
            sFilter := Fld.QuotedString ( '"' ) + Oper + sParam ;

         bWhere := false ;
         if Length ( AWhere ) = 0 then
         begin
            if Length ( AOrderBy ) <> 0 then
               iStart := AOrderBy[0].Start - Length ( cOrderBy )
            else
               iStart := AFrom[Length ( AFrom ) - 1].Start + AFrom[Length ( AFrom ) - 1].Length ;

            if sFilter <> '' then sFilter := cWhere + sFilter ;
         end
         else
         begin
            for i := 0 to Length ( AWhere ) - 1 do
            begin
               bWhere :=     ( AWhere[i].FieldName = Fld )
                         and (   not IsMasterDetail and ( AWhere[i].Quote = '''' )
                              or     IsMasterDetail and ( AWhere[i].Quote = '(' ) ) ;
               if bWhere then
               begin
                  iStart   := AWhere[i].Start ;
                  iReplLen := AWhere[i].Length ;
                  break ;
               end ;
            end ;

            if iReplLen = 0 then iStart := AWhere[0].Start ;

            if ( ( i < Length ( AWhere ) - 1 ) or ( iReplLen = 0 ) ) and ( Oper <> '' ) then sFilter := sFilter + 'and' ; // к последнему условию не добавлять

            if ( Oper = '' ) and ( Length ( AWhere ) = 1 ) then
            begin
               iStart   := iStart - Length ( cWhere ) ;
               iReplLen := iReplLen + Length ( cWhere ) ;
            end ;
         end ;
         if ( sFilter <> '' ) or bWhere then SQL.Text := StuffString ( SQL.Text , iStart + 1 , iReplLen , sFilter ) ;
      end ;
   finally
      ASelect  := nil ;
      AFrom    := nil ;
      AWhere   := nil ;
      AOrderBy := nil ;
   end ;
end ;

function TDM.SQLParse ( SQL : TStrings ; var ASelect : ASQLSelect ; var AFrom : ASQLFrom ; var AWhere : ASQLWhere ; var AOrderBy : ASQLOrderBy ) : boolean ; // true=support minifilter
var sSelect , sFrom , sWhere , sOrderBy , sObjectName : string ;
   i , j , k , iSelect , iFrom , iWhere , iOrderBy : integer ;
   bsav : boolean ;
   REx : TRegExpr ;
   SL : TStringList ;
// todo если первый символ ' ' после '(', то это master-detail
// todo если удаляем последний, то у предпоследнего нужно убрать разделитель
// todo если сумма длин where меньше общей длины, то минифильтр несовместим
begin
   try
      bsav := SQL.TrailingLineBreak ;
      SQL.TrailingLineBreak := false ;
      sSelect := SQL.Text ; // считаем, что там всегда будет только одна строка без добавленного CRLF в конце
   finally
      SQL.TrailingLineBreak := bsav ;
   end ;
   Result := ( sSelect <> '' ) ;

   if not Result then Exit ;

   REx := TRegExpr.Create ;
   try
      REx.Expression := '^'+ cSelect + '(".+"|\*)' + cFrom + '(".+")(?:' + cWhere+ '((?:"|\().+(?:\)|"|'')))?(?:' + cOrderBy + '(".+sc))?$' ;
      if REx.Exec ( sSelect ) then
      begin
         sSelect  := REx.Match[1] ; iSelect  := REx.MatchPos[1] - 1 ;
         sFrom    := REx.Match[2] ; iFrom    := REx.MatchPos[2] - 1 ;
         sWhere   := REx.Match[3] ; iWhere   := REx.MatchPos[3] - 1 ;
         sOrderBy := REx.Match[4] ; iOrderBy := REx.MatchPos[4] - 1 ;

         if sFrom <> '' then
         begin
            if assigned ( @AFrom ) or ( sSelect = '*'{получить список полей по sql объекту из From} ) then
            begin
               REx.Expression := '(?:(?:"([^"]+)")(?:\.|$))+?' ;
               if REx.Exec ( sFrom ) then
               begin
                  SL := TStringList.Create ;
                  try
                     i := 0 ;
                     j := REx.MatchPos[0] ;
                     repeat
                        SL.Add ( REx.Match[1] ) ;
                        i := i + REx.MatchLen[0] ;
                     until not REx.ExecNext ;
                     k := SL.Count ;
                     sObjectName := SL[k - 1] ;

                     if assigned ( @AFrom ) then
                     begin
                        SetLength ( AFrom , 1 ) ;

                        AFrom[0].ObjectName := SL[k - 1] ; // last=object,prev=schema,prev=db,prev=server
                        if 2 <= k then AFrom[0].Schema   := SL[k - 2] ; // схему используем только для разделения по пользователяем, т.е. имя объекта уникально во всех схемах
                        if 3 <= k then AFrom[0].DataBase := SL[k - 3] ;
                        if 4 <= k then AFrom[0].Server   := SL[k - 4] ;

                        AFrom[0].Start  := iFrom + j - 1 ; // for size counting to add "where"
                        AFrom[0].Length := i ;
                     end ;
                  finally
                     SL.Free ;
                  end ;
               end ;
            end ;
         end
         else
            if assigned ( @AFrom ) then AFrom := nil ;

         i := 0 ;
         if assigned ( @ASelect ) and ( sSelect <> '' ) then
            if sSelect = '*' then // todo парсить дерево запросов на предмет получения поля из базового объекта
            begin
               with QAttributesAll do
                  if Locate ( 'ObjectName' , sObjectName , [loCaseInsensitive] ) then
                     repeat
                        SetLength ( ASelect , i + 1 ) ;
                        ASelect[i].FieldName := FieldByName ( 'ColumnName' ).AsString ;
                        ASelect[i].Start     := 0 ;
                        ASelect[i].Length    := 0 ;
                        inc ( i ) ;
                        Next ;
                     until ( FieldByName ( 'ObjectName' ).AsString <> sObjectName ) or EOF ;
            end
            else
            begin
               REx.Expression := '(?:(?:"([^"]+)")(?:,|$))+?' ;
               if REx.Exec ( sSelect ) then
                  repeat
                     SetLength ( ASelect , i + 1 ) ;
                     ASelect[i].FieldName := REx.Match[1] ;
                     ASelect[i].Start     := iSelect + REx.MatchPos[0] - 1 ; // to replacing or deleting
                     ASelect[i].Length    := REx.MatchLen[0] ;
                     inc ( i ) ;
                  until not REx.ExecNext ;
            end
         else
            if assigned ( @ASelect ) then ASelect := nil ;

         if assigned ( @AWhere ) and ( sWhere <> '' ) then
         begin
            i := 0 ;
            k := 0 ;
            REx.Expression := '(?:(?:"([^"]+)"(' + cCompare + '|in)(''|\(|")([^''"]*)(''|\)|"))(?:and|$))+?' ; // todo добавить все сравнения, проверить '")( в значениях  // учитывая пустые значения
            if REx.Exec ( sWhere ) then
               repeat
                  SetLength ( AWhere , i + 1 ) ;
                  AWhere[i].FieldName  := REx.Match[1] ;
                  AWhere[i].Comparison := string ( REx.Match[2] ) ;
                  AWhere[i].Quote      := string ( REx.Match[3] ) ;
                  AWhere[i].Parameter  := REx.Match[4] ;
                  AWhere[i].Start      := iWhere + REx.MatchPos[0] - 1 ; // to replacing or deleting
                  AWhere[i].Length     := REx.MatchLen[0] ;
                  k := k + AWhere[i].Length ;
                  inc ( i ) ;
               until not REx.ExecNext ;

               Result := ( k = Length ( sWhere ) ) ; // наличие пропущенных условий есть несовместимость с минифильтром
         end
         else
            if assigned ( @AWhere ) then AWhere := nil ;

         if assigned ( @AOrderBy ) and ( sOrderBy <> '' ) then
         begin
            i := 0 ;
            REx.Expression := '(?:(?:"([^"]+)"(asc|desc))(?:,|$))+?' ;
            if REx.Exec ( sOrderBy ) then
               repeat
                  SetLength ( AOrderBy , i + 1 ) ;
                  AOrderBy[i].FieldName := REx.Match[1] ;
                  AOrderBy[i].Order     := string ( REx.Match[2] ) ;
                  AOrderBy[i].Start     := iOrderBy + REx.MatchPos[0] - 1 ; // to replacing or deleting
                  AOrderBy[i].Length    := REx.MatchLen[0] ;
                  inc ( i ) ;
               until not REx.ExecNext ;
         end
         else
            if assigned ( @AOrderBy ) then AOrderBy := nil ;
      end ;
   finally
      REx.Free ;
   end ;
end ;

procedure TDM.GetFilterOrder ( SQL : TStrings ; const FieldName : string ; var bFilter : boolean ; var sOrderBy : string ) ;
var AWhere : ASQLWhere = nil ;
    AOrderBy : ASQLOrderBy = nil ;
    i : integer ;
begin
   SetLength ( AWhere , 1 ) ;
   SetLength ( AOrderBy , 1 ) ;
   try
      SQLParse ( SQL , ASQLSelect ( nil^ ) , ASQLFrom ( nil^ ) , AWhere , AOrderBy ) ; // todo закешировать результат первого вызова

      for i := 0 to Length ( AWhere ) - 1 do
      begin
         bFilter := ( AWhere[i].FieldName = FieldName ) ;
         if bFilter then break ;
      end ;

      for i := 0 to Length ( AOrderBy ) - 1 do
         if AOrderBy[i].FieldName = FieldName then
         begin
            sOrderBy := AOrderBy[i].Order ;
            break ;
         end ;
   finally
      AWhere := nil ;
      AOrderBy := nil ;
   end ;
end ;

end.
