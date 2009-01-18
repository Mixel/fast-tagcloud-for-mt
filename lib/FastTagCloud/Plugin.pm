####
#### Fast Tag Cloud for MTOS 
#### By Mixel Adm                   Diciember del 2008
#### http://mixelandia.com


package FastTagCloud::Plugin;

use strict; use 5.006; use warnings; 
use MT 4.2;
# use Data::Dumper;
use MT::Log;
use MT::Util qw ( encode_url );



our $ftc_sth;
our $ftc_cache;
our @ftc_datos;

#### FTC  TAGS


sub ftc_tagcloud{
    my ($ctx, $args, $cond) = @_; #nuestros parametros
## depuracion
#    my $log = MT::Log->new;
#    $log->level(MT::Log::DEBUG());
#    $log->message(Dumper($ftc_cache));
#    $log->save or die $log->errstr;

    return $ftc_cache unless (!$ftc_cache); #si ya temos el contenido, entonces solo lo regresamos
    my $out; 
     my $i =0 ;
    my $max=0;
    my @temporal;

    my $limite = $args->{limit}?$args->{limit}:20; # el numero maximo de etiquetas, por default 20
    my $maxrank = $args->{maxrank}?$args->{maxrank}:10; #el numero maximo de ranks, por default 10
    my $orden =   'tag_name asc'; #por default ordenamos por nombre
    $orden = 'cuenta desc' if($args->{order}=='rank'); # solo en caso necesario por rank
    #Obtenemos las etiquetas desde la base de datos
    ftc_gettags($ctx->stash("blog_id"),$limite,$orden) or return();

    # Guardamos las etiquetas en un vector temporal, y obtenemos el valor maximo
    while (@ftc_datos = $ftc_sth->fetchrow_array() ){  
      $max = $ftc_datos[1] if ($ftc_datos[1] > $max);
      $temporal[$i] = [@ftc_datos];
      $i = $i + 1;
    }
    # calculamos los valores para el rank
    my $delta = ftc_prepare_rank($max,$i,$maxrank);
  
    $i = 0; #reiniciamos i

    #iniciamos la ruta de busqueda de las etiquetas
    my $ruta = ftc_ruta_busqueda($ctx); 
    #mientras que tengamos datos en el vector temporal
    while ($temporal[$i]){     
      $ftc_datos[0] = $temporal[$i][0]; #el nombre (name)
      $ftc_datos[1] = $temporal[$i][1]; #la cantidad (count)
      $ftc_datos[2] = ftc_tag_rank($temporal[$i][1],$maxrank,$delta); #el rank
      $ftc_datos[3] = $ruta . encode_url($ftc_datos[0]); #la ruta (path)
      defined(my $txt = $ctx->slurp($args,$cond)) or return; #evaluamos lo que viene desde la plantilla
      $out .= $txt; #concatenamos nuestra salida
      $i = $i +1;
    }
    #almacenamos la salida en el cache, asi no volvera a ser ejecutada hasta que se vuelva a cargar el plugin
    $ftc_cache= $out;
    return $out;
} 
## el nombre de la etiqueta
sub ftc_name{
    return $ftc_datos[0];
}
## el conteo de la etiqueta
sub ftc_count{
    return $ftc_datos[1];
}
## el rank de la etiqueta
sub ftc_rank{
    return $ftc_datos[2];
}
# la ruta de la etiqueta
sub ftc_link{
    return $ftc_datos[3];
}


#otras funciones auxiliares

## Calcula el valor de $delta
sub ftc_prepare_rank{  
  my ($max,$ntags,$maxrank) = @_;
  my $delta = ($maxrank-1) / log($max);  
  $delta = $delta * ($ntags/ $maxrank ) if($ntags < $maxrank);
  return $delta; 
}

## devuelve el rank de una etiqueta
sub ftc_tag_rank{
  my ($tagcount,$maxrank,$delta) = @_;   
  return $maxrank - int(log($tagcount) * $delta);
}

## Esta subrutina es la encargada de sacar los datos de la base de datos
sub ftc_gettags{

    my ($blog,$limite,$orden) = @_;
    my $od = MT::ObjectDriverFactory->new; # instanciamos el OD
    my $dbh = $od->fallback->rw_handle() ; # obtenemos un Manejador de la bd 
    #preparamos nuestra query
    $ftc_sth=$dbh->prepare("select tag_name,c.cuenta from mt_tag inner join (select count(objecttag_tag_id) as cuenta,objecttag_tag_id from mt_objecttag where objecttag_blog_id = ?  group by	 objecttag_tag_id order by cuenta desc limit ? ) c on c.objecttag_tag_id =tag_id group by tag_id order by $orden");
    # y la ejecutamos. Madamos 2 parametros que son el blog en el que estamos operando y el limite de etiquetas
    $ftc_sth->execute($blog,$limite) or die();    
}
## Devuelve la ruta de busqueda de las etiquetas
sub ftc_ruta_busqueda{
    # utilizamos el contexto para sacar varios datos
    my ($ctx) = @_;
    # mañosamente dejamos al final la etiqueta, asi simplemente la concatenamos cada vez que usemos la ruta
    my $parametros .= 'blog_id=' . $ctx->stash('blog_id') . '&amp;limit=' . $ctx->{config}->MaxResults. '&amp;tag=';
    my $ruta = $ctx->{config}->CGIPath;
    #codigo de MTOS para verificar si cgipath empieza en / y si es el caso, le agregamos la ruta del blog
    if ($ruta =~ m!^/!) {        
        if (my $blog = $ctx->stash('blog')) {
            my ($blog_domain) = $blog->archive_url =~ m|(.+://[^/]+)|;
            $ruta = $blog_domain . $ruta;
        }
    }
    return $ruta . $ctx->{config}->SearchScript . '?' . $parametros;
}




1;