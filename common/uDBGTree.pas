unit uDBGTree ;

interface

uses
   Classes , SysUtils , Forms , StdCtrls , Controls , SQLDB, DB
   , DBGrids
   //, DBGridsMy{������ ����� DBGrids,SQLDB}
   , uDBGTree1{������ ����� DBGrids,SQLDB} ;


type

   { TFrameDBGTree }

   TFrameDBGTree = class(TFrame)
    DBGTree: TDBGrid;
    DS: TDataSource;
    SQLQ: TSQLQuery;
   end;

implementation

{$R *.lfm}

end.
