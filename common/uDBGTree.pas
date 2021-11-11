unit uDBGTree ;

interface

uses
   Classes , SysUtils , Forms , StdCtrls , Controls , SQLDB, DB
   , DBGrids
   //, DBGridsMy{строго после DBGrids,SQLDB}
   , uDBGTree1{строго после DBGrids,SQLDB} ;


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
