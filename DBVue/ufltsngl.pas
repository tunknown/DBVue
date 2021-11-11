unit uFltSngl;

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons, DBCtrls, StdCtrls, SQLDB, DB , DBGrids
   , uDBGTree, uDBGTree1, ucForms, common ;

type

   TSQLQueryHack = class ( TSQLQuery ) ;
   TDBNavigatorHack = class ( TDBNavigator ) ;

   { TFFilterSingle }

   TFFilterSingle = class(TForm , ITFForm)
      BBSave: TBitBtn;
      BBCancel: TBitBtn;
      DBNavigator1: TDBNavigator;
      DSFilter: TDataSource;
      Edit1: TEdit;
      FrameDBGTree1: TFrameDBGTree;
      Panel1: TPanel;
      Panel2: TPanel;
      Panel3: TPanel;
      SQLQFilter: TSQLQuery;
      SQLQFilterSetup: TSQLQuery;
      procedure BBSaveClick(Sender: TObject);
      procedure Edit1Click(Sender: TObject);
   private
      procedure OnGetTextCaption ( Sender: TField ; var aText : string ; {%H-}DisplayText : Boolean ) ;
   public
      GridObject : string ;

      procedure SetParameters ( {%H-}DM : TDataModule ; Alias : string ; {%H-}Ig : TID ; {%H-}Desc : string ; {%H-}Selection : boolean ; {%H-}Value : TParams ) ; stdcall ;

      procedure GetIgDesc     ( var {%H-}Ig : TID ; var {%H-}Desc : string ) ; stdcall ;

      function  Search        : integer ; stdcall ;

      procedure GetCaptionText ( Sender : TField ; var aText : string ; {%H-}DisplayText : Boolean) ;
   end;

var
   FFilterSingle: TFFilterSingle;

implementation

uses StrUtils , Types , Grids , BufDataset , XMLDatapacketReader
     , commonDS
     , uDM ;

{$R *.lfm}

procedure TFFilterSingle.GetCaptionText ( Sender : TField ; var aText : string ; DisplayText : Boolean) ;
begin
   with SQLQFilter do
      aText := FieldByName ( 'Logic' ).AsString + FieldByName ( 'Param' ).DisplayText + FieldByName ( 'Operator' ).AsString + FieldByName ( 'Value' ).DisplayText ;
   DisplayText :=true ;
end ;

procedure TFFilterSingle.SetParameters ( DM : TDataModule ; Alias : string ; Ig : TID ; Desc : string ; Selection : boolean ; Value : TParams ) ; stdcall ;
var C : TColumn ;
   FCaption : TField ;
begin // Alias=GridObject->Редактирование, Alias=Class->Создание
   GridObject := Alias ;

   with TSQLQueryHack ( SQLQFilter ) do
   begin
      ParamByName ( 'sGridObject' ).AsString := Alias ;
      QInit ( SQLQFilter ) ;

      Cursor.FStatementType := stSelect ; // чтобы Edit не выдавал ReadOnly при редактировании хранимой процедуры нужен костыль; todo перенести в QInit?
   end ;
   TDBNavigatorHack ( DBNavigator1 ).EditingChanged ; // датасет теперь редактируемый

   FCaption := SQLQFilter.FindField ( 'Caption' ) ;
   if assigned ( FCaption ) then
      with FCaption do
      begin
         //DataSet := SQLQFilter ;
         //FieldName := Caption ;
         //Size := 256 ;
         //DisplayWidth := 25 ;
         Calculated := true ;
         FieldKind := fkCalculated ;
         //DisplayLabel := '***' ;
         //Visible := true ;
         OnGetText := @GetCaptionText ;
      end ;

   C := GetColumnByName ( FrameDBGTree1.DBGTree , 'Param' ) ;
   C.ButtonStyle := cbsPickList ;

   with DM1.QAttributesAll do
   if Locate ( 'ObjectName' , Alias {%H-}, [loCaseInsensitive] ) then
      repeat
         C.PickList.Add ( {todo ColumnName->Caption} FieldByName ( 'ColumnName' ).AsString ) ; // todo добавить список всех полей в поля Param,Value
         DM1.QAttributesAll.Next ;
      until ( FieldByName ( 'ObjectName' ).AsString <> Alias ) or EOF ;

   with GetColumnByName ( FrameDBGTree1.DBGTree , 'Value' ) do
   begin
      ButtonStyle := cbsPickList ;
      PickList.Assign ( C.PickList ) ;
   end ;

   with GetColumnByName ( FrameDBGTree1.DBGTree , 'Logic' ) , PickList do
   begin
      ButtonStyle := cbsPickList ;
      Add ( '(and)' ) ;
      Add ( '(or)'  ) ;
   end ;

   with GetColumnByName ( FrameDBGTree1.DBGTree , 'Operator' ) , PickList do
   begin
      ButtonStyle := cbsPickList ;
      Add ( ''        ) ;
      Add ( '='       ) ;
      Add ( '<'       ) ;
      Add ( '<='      ) ;
      Add ( '>'       ) ;
      Add ( '>='      ) ;
      Add ( '<>'      ) ;
      Add ( 'between' ) ;
      Add ( 'in'      ) ;
      Add ( 'not in'  ) ;
      Add ( 'like'    ) ;
   end ;

   with FrameDBGTree1.DBGTree.DataSource.DataSet do
   begin
      FieldByName ( 'Param' ).OnGetText := @OnGetTextCaption ;
      FieldByName ( 'Value' ).OnGetText := @OnGetTextCaption ;

      FieldByName ( 'Caption'  ).DisplayWidth := 40 ; // todo
      FieldByName ( 'Logic'    ).DisplayWidth := 7 ; // todo
      FieldByName ( 'Operator' ).DisplayWidth := 7 ; // todo
      FieldByName ( 'Param'    ).DisplayWidth := 15 ; // todo
      FieldByName ( 'Value'    ).DisplayWidth := 20 ; // todo
   end;
end ;

procedure TFFilterSingle.GetIgDesc     ( var Ig : TID ; var Desc : string ) ; stdcall ;
begin
end ;

function  TFFilterSingle.Search        : integer ; stdcall ;
begin
   Result := 0 ;
end ;

procedure TFFilterSingle.BBSaveClick(Sender: TObject);
var MS : TMemoryStream ;
   PO , PC , PT : TParam ;
   p : PChar ;
   s : PChar = 'encoding="utf-8"' ;
begin
   with SQLQFilterSetup do
      try
         MS := TMemoryStream.Create ;
         try
            SQLQFilter.SaveToStream ( MS , dfXML ) ;
            //MS.WriteByte ( 0 ) ; // с ним текстовый параметр формируется без последней кавычки
            p := StrPos ( MS.Memory , s ) ;
            if p <> nil then Fillchar ( p^ , length ( s ) , ' ' ) ; // todo поддерживать кодировку
            ParamByName ( 'sXML' ).LoadFromStream ( MS , ftMemo ) ;
         finally
            MS.Free ;
         end ;

         PO := ParamByName ( 'sGridObject'  ) ;
         PC := ParamByName ( 'sClass'   ) ;
         PT := ParamByName ( 'sCaption' ) ;
         if Pos ( '|' , GridObject ) <> 0 then
         begin
            PO.AsString := GridObject.QuotedString ( '"' ) ; //todo сделать единый формат имени объекта
            PC.Clear ;
            PT.Clear ;
         end
         else
         begin
            PO.Clear ;
            PC.AsString := GetClassFromStr ( GridObject ) ;
            PT.AsString := Edit1.Text ;
         end ;
         QInit ( SQLQFilterSetup ) ;
      finally
         Close ;
      end ;
end ;

procedure TFFilterSingle.Edit1Click(Sender: TObject);
begin
   FrameDBGTree1.DBGTree.Options := FrameDBGTree1.DBGTree.Options + [dgTitles] ;
end;

procedure TFFilterSingle.OnGetTextCaption ( Sender: TField ; var aText : string ; DisplayText : Boolean ) ;
var SA : TStringDynArray ;
begin // todo переделать на общую функцию получения полей
   if not assigned ( Sender ) then Exit ;

   try
      SA := SplitString ( Sender.AsString , '|' ) ;
      if 7 < Length ( SA ) then
      begin
         aText := '[' + SA[7] + ']' ;
         DisplayText := true ;
      end
      else
         aText := Sender.AsString ;
   finally
      SetLength ( SA , 0 ) ;
   end;
end ;

end.
