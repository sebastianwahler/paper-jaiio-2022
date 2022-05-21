drop table #tempPersonasSeleccionadas
drop table #tempPersonas
drop table #tempEnlaces
declare @top int
declare @mostrarGrupo bit
declare @mostrarFallecidos bit
declare @mostrarMenores bit
declare @mostrarJuridicas bit
declare @IdTituloDelito SMALLINT
declare @IdCapituloDelito SMALLINT
declare @IdTipoDelito SMALLINT
declare @listaPersonas varchar(200)

set @top = 30000
set @mostrarGrupo = 1
set @mostrarFallecidos = 1
set @mostrarMenores = 1
set @mostrarJuridicas = 1
set @IdTituloDelito = 0
set @IdCapituloDelito = 0
set @IdTipoDelito = 0
set @listaPersonas = ''

--*************************************************************
-- NODOS
--*************************************************************
declare @where varchar (5000) 
declare @from varchar (5000)

set @where = ''	
set @from =  ''
create table #tempPersonasSeleccionadas
(
	valor int, 
	idNodo int ,
	descripcion varchar (1000)

)

if (@top < 0) -- mostrar red de personas 
begin 
	select @top = COUNT (*) from RedGPNodo
	if (@listaPersonas != '' )  --seleccionó personas
		set @where = ' where IdNodo in (' + @listaPersonas + ')';
	insert into #tempPersonasSeleccionadas
	execute ('SELECT  valor, 
						 idNodo,
						 descripcion
						FROM redgpNodo N  ' 
						+  @where + ' order by valor DESC');

end
else
begin 
	if (@top = 0 ) -- todos los nodos sin top, devolver todos los nodos
		select @top = COUNT (*) from RedGPNodo
	insert into #tempPersonasSeleccionadas
	SELECT   valor,  idNodo,  descripcion
			FROM redgpNodo N 
			order by Valor DESC
end 

create table #tempPersonas
(
	value int, 
	id int ,
	label varchar (1000),
	fallecido bit,
	documento varchar (20)
)

if (@IdTipoDelito <> 0 OR @IdTituloDelito <> 0 OR @IdCapituloDelito <> 0 ) -- elegió algun tipo/capitulo/titulo delito, hacer inner y where de delitos
begin 
	insert into #tempPersonas
	SELECT top (@top)
		value = n.valor , 
		IdNacionalidad = n.idNodo,
		label = n.descripcion  , P.Fallecido, documento= p.NroDocumento
	FROM #tempPersonasSeleccionadas N inner join Persona P on N.IdNodo = P.IdPersona 
		inner join RedGPNodoRelacionEnlace NRE on N.idnodo =  NRE.idnodo
		LEFT JOIN Delito D ON D.idCaso = NRE.idrelacion
		LEFT JOIN TipoDelito TD ON TD.idTipoDelito = D.IdTipoDelito
		LEFT JOIN TipoDelitoCapitulo CD ON TD.idcapitulo = CD.idCapitulo
		LEFT JOIN TipoDelitoTitulo UD ON CD.idTitulo = UD.idTitulo 
		where ((@mostrarFallecidos = 0 AND P.Fallecido = 0 ) OR @mostrarFallecidos = 1)
		AND ((@mostrarJuridicas = 0 AND P.PersonaFisica = 1) OR (@mostrarJuridicas = 1 ))
		AND ((@mostrarMenores = 0 AND (dbo.fEsMenor (p.FechaNacimiento, p.edad2, p.menor, p.sindatosedad,getdate ()) = 0)) or @mostrarMenores = 1)
			AND (
			(@IdTipoDelito < 0 AND TD.descripcion is null) OR
			(D.IdTipoDelito = @IdTipoDelito ) OR
			(@IdTipoDelito = 0)
		)
	AND 	(CD.IdCapitulo  = @IdCapituloDelito OR @IdCapituloDelito = 0)
	AND 	(UD.IdTitulo  = @IdTituloDelito OR @IdTituloDelito = 0)

	order by valor DESC

end 
else -- si no eligio delito, no hacer inner con caso para no bajar performance
begin 

	insert into #tempPersonas
	SELECT top (@top)
		value = valor , 
		id = idNodo,
		label = descripcion  , Fallecido = P.Fallecido, documento = P.NroDocumento
	FROM #tempPersonasSeleccionadas N inner join Persona P on N.IdNodo = P.IdPersona 
	where ((@mostrarFallecidos = 0 AND P.Fallecido = 0 ) OR @mostrarFallecidos = 1)
		AND ((@mostrarJuridicas = 0 AND P.PersonaFisica = 1) OR (@mostrarJuridicas = 1 ))
		AND ((@mostrarMenores = 0 AND (dbo.fEsMenor (p.FechaNacimiento, p.edad2, p.menor, p.sindatosedad,getdate ()) = 0)) or @mostrarMenores = 1)

	order by valor DESC
end 
--*************************************************************
-- ENLACES
--*************************************************************
create table #tempEnlaces 
(
value int , 
	IDfrom int ,
	IDTo int , 
	DescripcionDesde varchar (1000) , DescripcionHasta varchar (1000)
)

insert into #tempEnlaces 
select value = e.Valor, 
	IDfrom = idnododesde,
	IDTo = idnodoHasta, E.DescripcionDesde, E.DescripcionHasta
from #tempPersonas TP inner join redgpEnlace E on (TP.id =  E.idnododesde or TP.id =  E.idNodoHasta)

--*************************************************************
-- GRUPO DE PERTENENCIA DE CADA NODO
--*************************************************************
if (@mostrarGrupo = 1) -- para cada nodo, mostrar su nodo enlace, muestra el grupo de pertenencia
begin 
	insert into #tempPersonas
	select value = valor, 
		id = idNodo,
		label = descripcion , Fallecido = P.Fallecido, documento = P.NroDocumento --  0 ,  '' --
	from redgpNodo N inner join #tempEnlaces TE on (N.idnodo =  TE.IDTo or N.idnodo =  TE.IDfrom)
	inner join Persona P on N.IdNodo = P.IdPersona
end

----********************************************************************
---- Ya estan generadas las tabla, devolver los datos según parametros
----********************************************************************


select distinct * from #tempPersonas
select distinct * from #tempEnlaces


