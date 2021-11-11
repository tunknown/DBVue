unit common ;
// miscelaneous without database and db-controls

interface

uses
   Windows , Classes ;

type
   TID = Variant;//type {$IF*NDEF FPC}variant{$ELSE}string[38]{$ENDIF} ; // '{00000000-0000-0000-0000-000000000000}' учитывая фигурные скобки

   {$IFNDEF FPC}function GetObjectProperty ( Obj : TObject ; Name : string ) : TObject ;{$ENDIF}
procedure SetObjectProperty ( Obj : TObject ; Name : string ; Value : TObject )  ;

function StringToNull ( s : string ) : Variant ;

procedure SLSetKeyAndValue ( SL : TStrings ; Key , Value : string ; DeleteOnEmpty : boolean = true ) ;
function SLGetValueOnKey ( SL : TStrings ; Key : string ; var Value : string ; OnlyValue : boolean = true ) : boolean ;
procedure SLCopyValue ( SLSrc         , SLDst : TStrings ; Key : string ; DeleteOnEmpty : boolean = true ) ; //overload ;
procedure SLCopyValueStr ( sSrc : string ; SLDst : TStrings ; Key : string ; DeleteOnEmpty : boolean = true ) ; //overload ;

function StrCount ( const substr , s : string ) : integer ;

function GetTempFileNameEx ( prefix : string = 'mmo' ; Extension : string = '' ) : string ;

function WithSelf ( const Proc : TThreadMethod ) : TObject ; {$IF Declared(CompilerVersion) and (CompilerVersion >= 18.0)}inline ;{$IFEND}

function IndexOfArray ( const A : integer ; const Arr : array of integer ) : integer ;
function IndexOfObject ( const AObject : TObject ; const AObjects : array of TObject ) : integer ;

function EnGUID ( g : TID ) : TID ;
function GUIDEmpty ( g : TID ) : boolean ;
function GUIDNotEmpty ( g : TID ) : boolean ;

function CombineDateAndTime ( ForDate , ForTime : TDateTime ) : TDateTime ;
function OffsetFromUTC : TDateTime ;

function  PostfixateComponent   ( Component : TComponent ; s : string = '' ) : string ;
function  DePostfixateComponent ( Component : TComponent ) : string ;

implementation

uses
   Variants , typinfo , StrUtils , sysutils , dialogs , forms ;

function StrCount ( const substr , s : string ) : integer ;
var i , j : integer ;
begin
   Result := -1 ;
   i := 1 ;

   while i < length ( s ) do
   begin
      j := 0 ;
      repeat
         inc ( j ) ;
      until ( j >= length ( substr ) ) or ( s[i + j - 1] <> substr[j] ) ;

      if s[i + j - 1] = substr[j] then
      begin
         inc ( Result ) ;
         inc ( i , length ( substr ) ) ;
      end
      else
         inc ( i ) ;
   end ;
end;

function StringToNull ( s : string ) : Variant ;
begin
   if s = '' then Result := Null else Result := s ;
end ;

procedure SLSetKeyAndValue ( SL : TStrings ; Key , Value : string ; DeleteOnEmpty : boolean = true ) ;
var i : integer ;
begin
   with SL do
   begin
      i := IndexOfName ( Key ) ;

      if ( i <> -1 ) then
         if ( Value = '' ) and DeleteOnEmpty then
            Delete ( i )
         else
            Values[Key] := Value
      else
         if ( Value <> '' ) or not DeleteOnEmpty then Append ( Key + '=' + Value ) ;
   end ;
end ;

function SLGetValueOnKey ( SL : TStrings ; Key : string ; var Value : string ; OnlyValue : boolean = true ) : boolean ;
var i : integer ;
begin
   with SL do
   begin
      i := IndexOfName ( Key ) ;
      Result := ( i <> -1 ) ;

      if not Result then
         Value := ''
      else
         if OnlyValue then
            Value := Values[Key]
         else
            Value := Strings[i]
   end ;
end ;

procedure SLCopyValue ( SLSrc , SLDst : TStrings ; Key : string ; DeleteOnEmpty : boolean = true ) ;
var s : string ;
begin
   SLGetValueOnKey ( SLSrc , Key , s ) ;
   SLSetKeyAndValue ( SLDst , Key , s , DeleteOnEmpty ) ; // выполнится в любом случае, даже если только для стирания
end ;

procedure SLCopyValueStr ( sSrc : string ; SLDst : TStrings ; Key : string ; DeleteOnEmpty : boolean = true ) ;
var SLSrc : TStrings ;
begin
   SLSrc := TStringList.Create ;
   try
      SLSrc.Text := sSrc ;
      SLCopyValue ( SLSrc , SLDst , Key , DeleteOnEmpty ) ;
   finally
      SLSrc.Free ;
   end ;
end ;


{$IFNDEF FPC}function GetObjectProperty ( Obj : TObject ; Name : string ) : TObject ;
var PropInfo : PPropInfo ;
begin
   Result := nil ;
   if not assigned ( Obj ) then Exit ;
   PropInfo := GetPropInfo ( Obj.ClassInfo , Name ) ;
   if not assigned ( PropInfo ) then Exit ;

   if PropInfo^.PropType^.Kind = tkClass then Result := TObject ( GetOrdProp ( Obj , PropInfo ) ) ;
end ;{$ENDIF}

procedure SetObjectProperty ( Obj : TObject ; Name : string ; Value : TObject )  ;
var PropInfo : PPropInfo ;
begin
   if not assigned ( Obj ) then Exit ;
   PropInfo := GetPropInfo ( Obj.ClassInfo , Name ) ;
   if not assigned ( PropInfo ) then Exit ;

   if PropInfo^.PropType^.Kind = tkClass then SetObjectProp ( Obj , Name , Value ) ;
end ;

function GetTempFileNameEx ( prefix : string = 'mmo' ; Extension : string = '' ) : string ;
var pathname , filename : string ;
begin
   SetLength ( pathname , MAX_PATH ) ;
   SetLength ( filename , MAX_PATH ) ;
   if Prefix = '' then Prefix := 'mmo' ;

   if pos ( '.' , Extension ) <> 1 then Extension := ExtractFileExt ( Extension ) ;

   if    ( GetTempPath ( MAX_PATH , PChar ( pathname ) ) = 0 )
      or ( GetTempFileName ( PChar ( pathname ) , PChar ( Prefix ) , 0 , PChar ( filename ) ) = 0 ) then ShowMessage ( 'Ошибка получения временного имени файла' ) ;
   Result := string ( PChar ( filename ) ) ;
   if Extension <> '' then Result := Result + Extension ;
end ;

function WithSelf ( const Proc : TThreadMethod ) : TObject ; {$IF Declared(CompilerVersion) and (CompilerVersion >= 18.0)}inline ;{$IFEND}
begin // получение "Self" внутри with; пример вызова: TForm ( WithSelf ( Free ) )
   Result := TObject ( TMethod ( Proc ).Data ) ;
end ;

function IndexOfArray ( const A : integer ; const Arr : array of integer ) : integer ;
var i : integer ;
begin
   for i := Low ( Arr ) to High ( Arr ) do
      if A = Arr[i] then
      begin
         Result := i ;
         Exit ;
      end ;
   Result := -1 ;
end ;

function IndexOfObject ( const AObject : TObject ; const AObjects : array of TObject ) : integer ;
var i : integer ;
begin
   for i := Low ( AObjects ) to High ( AObjects ) do
      if AObject = AObjects[i] then
      begin
         Result := i ;
         Exit ;
      end ;
   Result := -1 ;
end ;

function EnGUID ( g : TID ) : TID ;
begin // При компиляции в FPC даёт stack overflow
   if VarToStr ( g )[1] = '{' then Result := g else Result := '{' + g + '}' ;
end ;

function GUIDEmpty ( g : TID ) : boolean ;
begin // При компиляции в FPC даёт stack overflow
   Result := ( g = NULL ) or ( g = Unassigned ) ;
end ;

function GUIDNotEmpty ( g : TID ) : boolean ;
begin // При компиляции в FPC даёт stack overflow
   Result := ( g <> NULL ) and ( g <> Unassigned ) ;
end ;

function CombineDateAndTime ( ForDate , ForTime : TDateTime ) : TDateTime ;
begin
   ReplaceTime ( ForDate , 0 ) ;
   ReplaceDate ( ForTime , 0 ) ;
   Result := ForDate + ForTime ;
end ;

function OffsetFromUTC : TDateTime ;
var
   iBias : Integer ;
   tmez : TTimeZoneInformation ;
begin
   case GetTimeZoneInformation ( tmez ) of
      TIME_ZONE_ID_UNKNOWN :
         iBias := tmez.Bias ;
      TIME_ZONE_ID_DAYLIGHT :
         iBias := tmez.Bias + tmez.DaylightBias ;
      TIME_ZONE_ID_STANDARD:
         iBias := tmez.Bias + tmez.StandardBias ;
      else
         raise Exception.Create ( 'Ошибка получения часового пояса' ) ;
   end ;
   Result := EncodeTime ( Abs ( iBias ) div 60 , Abs ( iBias ) mod 60 , 0 , 0 ) ;
   if iBias > 0 then Result := -Result ;
end ;
////////////////////////////////////////////////////////////////////////////////////////////////////
function GetUniquePostfix : TComponentName ;
begin
   Result := FormatDateTime ( '_yymmddhhnnsszzz' , now ) ;
end ;

function CheckPostfix ( s : string ) : boolean ;
var e : integer ;
    r : int64 ;
begin // возвращение исходного имени компонента
   Result :=     ( length ( s ) = length ( GetUniquePostfix ) )
             and ( LeftStr ( s , 1 ) = '_' ) ;

   if Result then
   begin
      s := RightStr ( s , length ( s ) - 1 ) ;

      Val ( s , r , E ) ;
      Result := ( E = 0 ) and ( r <> 0 ) ;
   end ;
end ;

function PostfixateComponent ( Component : TComponent ; s : string = '' ) : string ;
begin // уникализация имени компонента, например, повторно создаваемого
   if ( s <> '' ) and CheckPostfix ( s ) then Result := s else Result := GetUniquePostfix ;

   //GetObjectProperty ( Component , 'Caption' )
   if Component is TForm then s := TForm ( Component ).Caption ;

   try
      Component.Name := Component.Name + Result ;
   finally
      if Component is TForm then TForm ( Component ).Caption := s ;
   end;
end ;

function DePostfixateComponent ( Component : TComponent ) : string ;
var s : string ;
begin // возвращение исходного имени компонента
   Result := '' ;

   s := RightStr ( Component.Name , length ( GetUniquePostfix ) ) ;

   if CheckPostfix ( s ) then
   begin
      Result := s ;

      Component.Name := LeftStr ( Component.Name , Length ( Component.Name ) - length ( GetUniquePostfix ) ) ;
   end ;
end ;

end.
