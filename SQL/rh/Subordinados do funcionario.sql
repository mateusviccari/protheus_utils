/*
Função que retorna os subordinados de um funcionário com nível de recursividade.
*/
CREATE function rh.subordinados_do_funcionario(@codigo_funcionario varchar(15), @nivel smallint, @trazer_niveis_inferiores bit)
returns @retorno table(
	codigo_superior varchar(15),
	codigo varchar(15),
	departamento varchar(15),
	nivel smallint
)
begin
	if @nivel is null begin
		set @nivel = 0;
	end;

	if @trazer_niveis_inferiores is null begin
		set @trazer_niveis_inferiores = 0;
	end;

	insert into @retorno(codigo_superior, codigo, departamento, nivel)
	SELECT
	@codigo_funcionario as codigo_superior,
	RA_MAT as codigo,
	RA_DEPTO as departamento,
	@nivel + 1 as nivel
	from PROTHEUS_DB.dbo.SQB010 as depto with(nolock) 
	inner join PROTHEUS_DB.dbo.SRA010 as subord with(nolock)
		on subord.D_E_L_E_T_ = '' and subord.RA_FILIAL = '00'
		and subord.RA_DEPTO = QB_DEPTO
		and subord.RA_MAT <> @codigo_funcionario
		and subord.RA_SITFOLH <> 'D'
	where depto.D_E_L_E_T_ = '' and QB_FILIAL = ''
	and QB_MATRESP = @codigo_funcionario;

	if (@trazer_niveis_inferiores = 1) begin
		insert into @retorno(codigo_superior, codigo, departamento, nivel)
		select
		subord.RA_MAT, codigo, departamento, nivel
		from PROTHEUS_DB.dbo.SQB010 as depto with(nolock) 
		inner join PROTHEUS_DB.dbo.SRA010 as subord with(nolock)
			on subord.D_E_L_E_T_ = '' and subord.RA_FILIAL = '00'
			and subord.RA_DEPTO = QB_DEPTO
			and subord.RA_MAT <> @codigo_funcionario
			and subord.RA_SITFOLH <> 'D'
		cross apply (
			select codigo_superior, codigo, departamento, nivel
			from rh.subordinados_do_funcionario(subord.RA_MAT, @nivel+1, @trazer_niveis_inferiores)
		) as s
		where depto.D_E_L_E_T_ = '' and QB_FILIAL = ''
		and QB_MATRESP = @codigo_funcionario
		and (select count(*) from PROTHEUS_DB.dbo.SQB010 as QBX where QBX.D_E_L_E_T_ = '' and QBX.QB_FILIAL = '' and QBX.QB_MATRESP = subord.RA_MAT) > 0;
	end

	return;
end