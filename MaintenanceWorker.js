addEventListener("fetch", event => {
  event.respondWith(fetchAndReplace(event.request))
})

async function fetchAndReplace(request) {

  let modifiedHeaders = new Headers()

  modifiedHeaders.set('Content-Type', 'text/html')
  modifiedHeaders.append('Pragma', 'no-cache')


  //Return maint page if you're not calling from a trusted IP
  if (request.headers.get("cf-connecting-ip") !== "123.123.123.123") 
  {
    // Return modified response.
    return new Response(maintPage, {
      headers: modifiedHeaders
    })
  }
  else //Allow users from trusted into site
  {
    //Fire all other requests directly to our WebServers
    return fetch(request)
  }
}

let maintPage = `

<!doctype html>
<title>Site Maintenance</title>
<style>
  body { 
        text-align: center; 
        padding: 150px; 
        background: url('data:image/jpeg;base64,<base64EncodedImage>'); 
        background-size: cover;
        -webkit-background-size: cover;
        -moz-background-size: cover;
        -o-background-size: cover;
      }

    .content {
        background-color: rgba(255, 255, 255, 0.75); 
        background-size: 100%;      
        color: inherit;
        padding-top: 1px;
        padding-bottom: 10px;
        padding-left: 100px;
        padding-right: 100px;
        border-radius: 15px;        
    }

  h1 { font-size: 40pt;}
  body { font: 20px Helvetica, sans-serif; color: #333; }
  article { display: block; text-align: left; width: 75%; margin: 0 auto; }
  a:hover { color: #333; text-decoration: none; }  


</style>

<article>

        <div class="background">
            <div class="content">
        <h1>We&rsquo;ll be back soon!</h1>        
            <p>We're very orry for the inconvenience but we&rsquo;re performing maintenance. Please check back soon...</p>
            <p>&mdash; <B><font color="red">{</font></B>RESDEVOPS<B><font color="red">}</font></B> Team</p>
        </div>
    </div>

</article>
`;