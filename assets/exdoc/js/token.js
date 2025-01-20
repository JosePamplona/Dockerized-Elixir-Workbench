// token.js v1.0.0
// This script is injected at the end of the <body> tag on all ExDoc generated 
// HTML files, to enable image version switch on page theme change.
console.info(
  `ExDoc | body injected script: %ctoken.js %cv1.0.0`,
  'font-weight: bold;',
  'color: #3d6fe3;'
)

// https://dev-gbzpl2r6u5042o0y.us.auth0.com/authorize
// client_id=gA948oBZk6EPjwG1Sr7XZldLOWHjEoMn
// response_type=code
// prompt=login
// scope=openid%20profile
// redirect_uri=https://manage.auth0.com/tester/callback

function setTokenButton() {
  let reference = document.querySelector(`code[class="auth_token"]`);
  if(reference) {
    reference.style.display = 'none';

    const displayStyle = `
      padding: 1rem;
      line-height: 1.3em;
      white-space: pre-wrap;
      word-break: break-word;
      overflow-wrap: anywhere;
      display: none;
      font-family: monospace,monospace;
      font-size: 1em;
      `;
    
    const buttonStyle = `
      display:          inline-flex;
      -moz-box-align:   center;
      align-items:      center;
      -moz-box-pack:    center;
      justify-content:  center;
      position:         relative;
      box-sizing:       border-box;
      outline:          0px;
      border:           0px;
      margin:           0px;
      cursor:           pointer;
      user-select:      none;
      vertical-align:   middle;
      appearance:       none;
      text-decoration:  none;
      font-weight:      700;
      line-height:      1.71429;
      text-transform:   unset;
      font-family:      "__Public_Sans_d7c01c", "__Public_Sans_Fallback_d7c01c", Helvetica, Arial, sans-serif;
      min-width:        64px;
      padding:          8px 16px;
      border-radius:    8px;
      transition:       background-color 250ms cubic-bezier(0.4, 0, 0.2, 1),
                        box-shadow 250ms cubic-bezier(0.4, 0, 0.2, 1),
                        border-color 250ms cubic-bezier(0.4, 0, 0.2, 1),
                        color 250ms cubic-bezier(0.4, 0, 0.2, 1);
      color:            rgb(255, 255, 255);
      background-color: rgb(135, 117, 228);
      box-shadow:       none;
      height:           48px;
      font-size:        15px;
      width:            202px;
      margin-right:     1em;
      `;
      // background-color: rgb(159, 144, 234);
      // background-color: rgb(103, 79,  222);

    let userDisplay = document.createElement("blockquote");
    let tokenDisplay = document.createElement("blockquote");
    userDisplay.style = displayStyle;
    tokenDisplay.style = displayStyle;
    
    let testerButton = document.createElement("button");
    testerButton.style = buttonStyle
    testerButton.textContent = "Log in tester";
    testerButton.id = 'log_in_tester';
    testerButton.addEventListener("click", async (e) => {
      window.open(`https://${
        authConfig.domain
      }/authorize?client_id=${
        authConfig.client_id
      }&response_type=code&prompt=login&scope=openid%20profile&redirect_uri=https://manage.auth0.com/tester/callback`, '_blank');
    });

    let tokenButton = document.createElement("button");
    tokenButton.style = buttonStyle
    tokenButton.textContent = "Request token";
    tokenButton.id = 'request_token';

    reference.parentNode.insertBefore(tokenButton, reference);
    reference.parentNode.insertBefore(testerButton, reference);
    reference.parentNode.insertBefore(userDisplay, reference);
    reference.parentNode.insertBefore(tokenDisplay, reference);

    if(typeof authConfig !== 'undefined') {
      auth0.createAuth0Client({
        domain: authConfig.domain,
        clientId: authConfig.client_id,
        authorizationParams: {
          redirect_uri: window.location.origin,
          audience: `https://${authConfig.domain}/api/v2/`,
          scopes: 'openid profile email'
        }
      }).then(async (auth0Client) => {
        const loginButton = tokenButton;
      
        loginButton.addEventListener("click", async (e) => {
          e.preventDefault();
  
          try {
            await auth0Client.loginWithPopup();          
            const isAuthenticated = await auth0Client.isAuthenticated();
            const userProfile = await auth0Client.getUser();
              
            if (isAuthenticated) {
  
              const token = await auth0Client.getTokenSilently();
  
              userDisplay.style.display = 'flex';
              userDisplay.innerHTML = `<img alt='profile' src='${
                userProfile.picture
              }' width='96px' height='96px'/><div style='margin: 0 0 0 1em;'>${
                JSON.stringify(userProfile, null, 2)
              }<div>`;
  
              tokenDisplay.style.display = 'flex';
              tokenDisplay.innerHTML = `<div>${JSON.stringify({
                authorization: `Bearer ${token}`
              }, null, 2)}<div>`;
            }
  
          } catch(e) {          
            tokenDisplay.style.display = 'none';
            userDisplay.style.display = 'flex';
            userDisplay.innerHTML = `Popup was closed before login completed`;
          }
        });
      });
    } else {
      tokenDisplay.style.display = 'none';
      userDisplay.style.display = 'flex';
      userDisplay.innerHTML = `Configuration variables not found`;
    }
  }
}

// -----------------------------------------------------------------------------

document.addEventListener("DOMContentLoaded", setTokenButton());
