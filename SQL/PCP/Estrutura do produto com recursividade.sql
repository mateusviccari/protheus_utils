
/*
@codigo_produto = Código do produto principal
@quantidade_base = Quantidade base do produto principal (padrão = 1)
@nivel = Nível inicial da estrutura (padrão = 0)
@mostra_intermediarios = Indica se produtos intermediários (que possuem estrutura própria) devem ser exibidos (padrão = 0 - não exibe)

Exemplo de uso:
select R.B1_COD, R.B1_DESC, estr.*
from SB1010 as R with(nolock)
cross apply (
	select codigo, quantidade, perda, codigo_superior, nivel, intermediario, ordem_hierarquica
	from MY_DB.estoque.estrutura_com_recursividade(R.B1_COD, R.B1_QB, 0, 1)
) as estr
inner join SB1010 as I with(nolock) on I.D_E_L_E_T_ = '' and I.B1_FILIAL = '00' and I.B1_COD = estr.codigo collate latin1_general_bin
where R.D_E_L_E_T_ = '' and R.B1_FILIAL = '00'
and R.B1_COD = '000001'
*/
CREATE function estoque.estrutura_com_recursividade(@codigo_produto varchar(15), @quantidade_base float, @nivel smallint, @mostra_intermediarios bit)
returns @retorno table(
	codigo_superior varchar(15),
	codigo varchar(15),
	quantidade float,
	perda float,
	nivel smallint,
	intermediario bit,
	ordem_hierarquica varchar(max)
)
begin
	if @quantidade_base is null or @quantidade_base = 0 begin
		set @quantidade_base = 1;
	end;

	if @nivel is null begin
		set @nivel = 0;
	end;

	if @mostra_intermediarios is null begin
		set @mostra_intermediarios = 0;
	end;

	--Busca os ingredientes diretos (sem estrutura própria)
	insert into @retorno(codigo_superior, codigo, quantidade, perda, nivel, intermediario, ordem_hierarquica)
	SELECT
	G1_COD as codigo_superior,
	G1_COMP as codigo,
	(G1_QUANT / produto_pai.qtd_base) * @quantidade_base as quantidade,
	G1_PERDA as perda,
	@nivel + 1 as nivel,
	intermediario.eh,
	trim(@codigo_produto) + ' > ' + trim(G1_COMP)
	from PROTHEUS_DB.dbo.SG1010 as G1 with(nolock)
	inner join PROTHEUS_DB.dbo.SB1010 as B1R with(nolock) on B1R.D_E_L_E_T_ = '' and B1R.B1_FILIAL = '00' and B1R.B1_COD = G1.G1_COD
	cross apply (select case when B1R.B1_QB = 0 then 1 else B1R.B1_QB end as qtd_base) as produto_pai
	cross apply (
		select case when exists
			(select 1 from PROTHEUS_DB.dbo.SG1010 as G1I with(nolock)
			where G1I.D_E_L_E_T_ = '' and G1I.G1_FILIAL = '00' and G1I.G1_COD = G1.G1_COMP)
			then 1 else 0 end
	) as intermediario(eh)
	where G1.D_E_L_E_T_ = '' and G1_FILIAL = '00'
	and (
		intermediario.eh = 0
		or @mostra_intermediarios = 1
	)
	and G1_COD = @codigo_produto;

	--Busca os ingredientes dos produtos intermediário (que possuem estrutura própria) via recursividade
	insert into @retorno(codigo_superior, codigo, quantidade, perda, nivel, intermediario, ordem_hierarquica)
	SELECT
	codigo_superior, codigo, quantidade, perda, nivel + 1, intermediario, trim(@codigo_produto) + ' > ' + ordem_hierarquica
	from PROTHEUS_DB.dbo.SG1010 as G1 with(nolock)
	inner join PROTHEUS_DB.dbo.SB1010 as B1R with(nolock) on B1R.D_E_L_E_T_ = '' and B1R.B1_FILIAL = '00' and B1R.B1_COD = G1.G1_COD
	cross apply (select case when B1R.B1_QB = 0 then 1 else B1R.B1_QB end as qtd_base) as produto_pai
	cross apply (
		select codigo_superior, codigo, quantidade, perda, nivel, intermediario, ordem_hierarquica
		from estoque.estrutura_com_recursividade(G1.G1_COMP, (G1.G1_QUANT / produto_pai.qtd_base) * @quantidade_base, @nivel, @mostra_intermediarios)
	) as filhos
	where G1.D_E_L_E_T_ = '' and G1_FILIAL = '00'
	and (select count(*) from PROTHEUS_DB.dbo.SG1010 as G1I with(nolock) where G1I.D_E_L_E_T_ = '' and G1I.G1_FILIAL = '00' and G1I.G1_COD = G1.G1_COMP) > 0
	and G1_COD = @codigo_produto;

	return;
end