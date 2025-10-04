CREATE function pcp.comparar_pre_estrutura(@produto varchar(15))
returns @retorno table(
	componente varchar(15),
	nome varchar(120),
	qtd_antiga float,
	qtd_nova float, 
	tipo_operacao varchar(20),
	cor_operacao varchar(10)
)
begin
	
	insert into @retorno(componente, nome, qtd_antiga, qtd_nova, tipo_operacao, cor_operacao)
	select componente, B1_DESC as nome, qtd_antiga, qtd_nova, operacao.tipo as tipo_operacao, cor_operacao.cor as cor_operacao
	from (
		select componente, coalesce(sum(qtd_antiga), 0) as qtd_antiga, coalesce(sum(qtd_nova), 0) as qtd_nova from (
			select G1_COMP as componente, G1_QUANT as qtd_antiga, 0 as qtd_nova
			from PROTHEUS_DB.dbo.SG1010 as G1
			where G1.D_E_L_E_T_ = '' and G1_FILIAL = '00'
			and G1_COD = @produto
			union all
			SELECT GG_COMP as componente, 0 as qtd_antiga, GG_QUANT as qtd_nova
			from PROTHEUS_DB.dbo.SGG010 as GG
			where D_E_L_E_T_ = '' and GG_FILIAL = '00'
			and GG_COD = @produto
		) as tabelas
		group by componente
	) as comparacao
	inner join PROTHEUS_DB.dbo.SB1010 as B1 on B1.D_E_L_E_T_ = '' and B1_FILIAL = '00' and B1_COD = componente
	cross apply (select case
		when qtd_antiga = qtd_nova then ''
		when qtd_antiga = 0 then 'INCLUSAO'
		when qtd_nova = 0 then 'EXCLUSAO'
		else 'ALTERACAO' end
	) as operacao(tipo)
	cross apply (select case
		when operacao.tipo = 'INCLUSAO' then '#080'
		when operacao.tipo = 'EXCLUSAO' then '#800'
		when operacao.tipo = 'ALTERACAO' then '#00C'
		else '#000' end
	) as cor_operacao(cor)
	where exists (select 1 from PROTHEUS_DB.dbo.SGG010 where D_E_L_E_T_ = '' and GG_FILIAL = '00' and GG_COD = @produto)
	order by abs(qtd_antiga - qtd_nova) desc, componente;
	
	return;
end