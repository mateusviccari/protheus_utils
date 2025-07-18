/*
Função para SQL SERVER!
Necessário criar a função KeepAlphanumericAndSpace disponível em:
https://github.com/mateusviccari/useful_sqls/blob/main/functions/SQL%20Server/keep_alphanumeric_and_space.sql
A lógica deste SQL é a seguinte:
Dentro da SYS_USR_MODULE buscará a relação de acesso entre usuários X módulos.
Para buscar as rotinas dentro do módulo, o protheus grava na tabela MP_SYSTEM_PROFILE onde
-Campo P_TYPE = 'ACBROWSE'
-Usuário no campo P_NAME (as vezes grava o id, outras o login por alguma razão que só a totvs sabe).
-No campo P_PROG vai o nome do módulo
Porém nesta tabela existe apenas uma linha por usuário X módulo.
As rotinas em si ficam armazenadas todas dentro da coluna P_DEFS que é um varbinary.
Se transformar essa coluna pra varchar trará caracteres inválidos, que retiraremos pra facilitar
usando a função KeepAlphanumericAndSpace.
Depois de tratado, retornará algo como AACProdutosCECMATA010Cxx xxxxxxxACUnidades MedidaCDCQIEA030Cxxxxxxxxxx..
Basicamente quando existe o nome desta rotina dentro do campo, significa que foi feita alguma restrição nesta rotina,
seja retirando o acesso (a string conterá 'CDC'+ROTINA) ou limitando alguma das
opções [incluir, visualizar, excluir, etc] (a string conterá 'CEC'+ROTINA+'C'+PERMISSOES).
Caso a rotina não estiver dentro do campo, significa que o usuário possui permissão total à ela.
Caso não exista nenhum registro na tabela MP_SYSTEM_PROFILE para este usuário X módulo, significa que foi liberado o
acesso ao módulo para este usuário e foram mantidos os acessos totais em todas as rotinas.
Este SQL traz somente os usuários ativos, e cujo funcionário (caso houver vinculo funcional) não esteja demitido.
Recomendo filtrar por módulo pois pelo fato de ter que fazer a pesquisa na MP_SYSTEM_PROFILE torna a consulta demorada.
*/

select
usuario.USR_ID as "Id usuário",
usuario.USR_NOME as "Usuário",
trim(modulo.USR_CODMOD) as "Módulo",
trim(funcao.F_FUNCTION) as "Função",
trim(nome_menu.N_DESC) as "Nome função",
permissao_rotina.permissao as "Permissão"
from SYS_USR_MODULE as modulo
inner join SYS_USR as usuario on usuario.USR_ID = modulo.USR_ID
left join SYS_USR_VINCFUNC as vinculo_funcional on vinculo_funcional.USR_ID = usuario.USR_ID
left join SRA010 as funcionario on funcionario.RA_MAT = vinculo_funcional.USR_CODFUNC
inner join MPMENU_ITEM as acesso on acesso.I_ID_MENU = modulo.USR_ARQMENU
left join MPMENU_I18N as nome_menu on nome_menu.N_PAREN_ID = acesso.I_ID and nome_menu.N_LANG = 1
inner join MPMENU_FUNCTION as funcao on funcao.F_ID = acesso.I_ID_FUNC
outer apply (
	select coalesce((
		select
		case
			when defs_str like '%CDC' + trim(funcao.F_FUNCTION) + '%' then 'SEM_PERMISSAO'
			when defs_str like '%CEC' + trim(funcao.F_FUNCTION) + '%' then 'PERMISSAO_PARCIAL'
			when defs_str not like '%' + trim(funcao.F_FUNCTION) + '%' then 'PERMISSAO_TOTAL'
		end
		from MP_SYSTEM_PROFILE as profile
		cross apply (select dbo.KeepAlphanumericAndSpace(cast(P_DEFS as varchar(max)))) as defs_str(defs_str)
		where profile.D_E_L_E_T_  = ''
		and P_TYPE = 'ACBROWSE'
		and profile.P_NAME in (usuario.USR_ID, usuario.USR_CODIGO)
		and P_PROG = modulo.USR_CODMOD
	), 'PERMISSAO_TOTAL') as permissao
) as permissao_rotina
where 1=1
and modulo.USR_ACESSO = 'T'
and usuario.USR_MSBLQL = '2'
and (funcionario.RA_MAT is null or funcionario.RA_SITFOLH <> 'D')
and modulo.USR_CODMOD = 'SIGAFIN'
--and funcao.F_FUNCTION = 'FINA750'
order by usuario.USR_NOME