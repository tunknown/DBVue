set	nocount	on

begin	tran

declare	@sWhere		nvarchar ( max )
	,@c		varchar ( 1 )
	,@sBehavior	varchar ( 16 )
	,@sParam	nvarchar ( 256 )
	,@sOp		varchar ( 16 )
	,@sValue	nvarchar ( 4000 )
	,@sRest		nvarchar ( 4000 )
	,@s1		nvarchar ( 2 )
	,@s2		nvarchar ( 16 )
	,@iParent	smallint
	,@i		smallint
	,@bNeedOp	bit
----------
select	@sWhere=	'(([f1]>''-1''or[f1]like''9%''or[f1]=[f1])and([Moment]>''20130101''or[f2]<>''dfgdf''''dfgdfg''or[f1]=''1''or[f1]is null ))'	*** ��������� ������� � ������ �� ��������
	,@sRest=	@sWhere
	,@bNeedOp=	1
----------
create	table	#SyntaxTree
(	Id		smallint		not null	identity ( 1,	1 )
	,Parent		smallint		null
	,Behavior	varchar ( 16 )		null
	,Param		nvarchar ( 256 )	null
	,Op		varchar ( 16 )		null
	,Value		nvarchar ( 4000 )	null
,check	(	Param+	Op+	Value	is	not	null
	or	coalesce ( Param,	Op/*,	Value*/ )	is	null )	)	-- [param]is_null_  ��� ��������� null
----------
		select	FieldName=	'f1'	into	#Fields
union	all	select	FieldName=	'f2'
union	all	select	FieldName=	'Moment'
----------
while	''<	@sRest
begin
	if	left ( @sRest,	1 )=	'('
	begin
		insert	#SyntaxTree	( Parent,	Behavior )
		select	@iParent,	@sBehavior
----------
		select	@iParent=	scope_identity()
			,@sRest=	right ( @sRest,	len ( @sRest )-	1 )
----------
		continue	-- �������������, �.�. ������� ������ ����� ���� ������ � ��� ��������� �������� if @bNeedOp=1
	end
----------
	if		left ( @sRest,	1 )=	'['
		and	@bNeedOp=		1
	begin
		select
			@sParam=	FieldName
			,@sRest=	right ( @sRest,	len ( @sRest )-	len ( quotename ( FieldName ) ) )
		from
			#Fields						-- �� ����� ���� � ������� ���� ����, �������� �������� ��������� ���������� � ������, �.�. quotename
		where
			left ( @sRest,	len ( quotename ( FieldName ) ) )=	quotename ( FieldName )		-- like ������ ��-�� ���������� ������� ������������ [ %
----------
		if	@@RowCount<>	1
			raiserror ( '������ 1',	18,	1 )
	end
----------
	if	@bNeedOp=	1
	begin
		set	@i=	patindex ( '%[''[ ]%',	@sRest )
		if	@i<>	0
			select	@sOp=		substring ( @sRest,	1,	@i-	1 )
				,@sRest=	right ( @sRest,	len ( @sRest )-	len ( @sOp ) )
		else
			raiserror ( '������ 2',	18,	1 )
----------
		set	@bNeedOp=	0
	end
----------
	set	@s1=	left ( @sRest,	1 )
----------
	if	@s1	in	( '''',	'[',	' ' )						-- ���� ��������� ������ ��������� ��������
	begin
		select	@sRest=		right ( @sRest,	len ( @sRest )-	1 )			-- ������ ������ ���������
			,@s2=		case	@s1
						when	''''	then	'%[^'']''[^'']%'	-- ���� ��������� �������, ����������� ��������, � �� ������� ��� �����������
						when	'['	then	'%]%'
						else			'%['+	@s1+	']%'
					end
			,@i=			patindex ( @s2,	@sRest )			-- ����� ������ ����������� �������� ������
					+	case	@s1
							when	'['	then	0		-- ������ ���������� ����� ����� %
							else			1		-- ������ ���������� ����� %[
						end
		if	@i<>	0
			select	@sValue=	substring ( @sRest,	1,	@i-	1 )
				,@sRest=	right ( @sRest,	len ( @sRest )-	@i )		-- ����������� ������ ��������
		else
			raiserror ( '������ 3',	18,	1 )
----------
		insert	#SyntaxTree	( Parent,	Behavior,	Param,	Op,	Value )
		select	@iParent,	@sBehavior,	@sParam,	@sOp,	@sValue
----------
		set	@sBehavior=	null
	end
----------
	if	left ( @sRest,	1 )=	')'
	begin
		select
			@iParent=	Parent
			,@sRest=	right ( @sRest,	len ( @sRest )-	1 )
		from
			#SyntaxTree
		where
			Id=	@iParent
	end
	else
	begin
		set	@i=	patindex ( '%[([]%',	@sRest )
		if	@i<>	0
			select	@sBehavior=	substring ( @sRest,	1,	@i-	1 )
				,@sRest=	right ( @sRest,	len ( @sRest )-	len ( @sBehavior ) )
				,@bNeedOp=	1
		else
			raiserror ( '������ 4',	18,	1 )
	end
end
----------
select
	*
from
	#SyntaxTree
order	by
	Id

rollback