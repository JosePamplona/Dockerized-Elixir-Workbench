// themedImage.js v1.0.0
// This script is injected at the end of the <body> tag on all ExDoc generated 
// HTML files, to enable image version switch on page theme change.
console.info(
  `ExDoc | body injected script: %cthemedImage.js %cv1.0.0`,
  'font-weight: bold;',
  'color: #3d6fe3;'
)

// ExDoc HTML page settings
// console.log(settings)

// ClassWatcher objects will trigger designated functions whenever a specific
// class is added or removed from an element.
class ClassWatcher {
  constructor(targetNode, classToWatch, classAddedCallback, classRemovedCallback) {
    this.targetNode = targetNode
    this.classToWatch = classToWatch
    this.classAddedCallback = classAddedCallback
    this.classRemovedCallback = classRemovedCallback
    this.observer = null
    this.lastClassState = targetNode.classList.contains(this.classToWatch)
    this.init()
  }

  init() {
    this.observer = new MutationObserver(this.mutationCallback)
    this.observe()
  }

  observe() {
    this.observer.observe(this.targetNode, { attributes: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  mutationCallback = mutationsList => {
    for(let mutation of mutationsList) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
        let currentClassState = mutation.target.classList.contains(this.classToWatch)
        if(this.lastClassState !== currentClassState) {
          this.lastClassState = currentClassState
          if(currentClassState) {
            this.classAddedCallback()
          }
          else {
            this.classRemovedCallback()
          }
        }
      }
    }
  }
}

// Search for an <img src='original_src'>:
// If none found, does nothing. If an element is found, checks:
// If the <body> tag have the class 'dark' sets the img.src='dark_src',
// If the <body> tag doesn't have the class 'dark' sets the img.src='light_src'.
// Add a listener on body element to keep updating src whenever class changes.
function setThemedImage(original_src, light_src, dark_src) {
  // Class of the body element to listen for changes
  const target_class = 'dark';

  // Preload the two images to avoid BINDING errors.
  const lightImage = new Image(); lightImage.src = light_src;
  const darkImage  = new Image(); darkImage.src  = dark_src;
  
  // The image element is determined by searching for:
  // An unique <img> tag with img.src == light or img.src == dark.
  let img = document.querySelector(`img[src="${original_src}"]`);
  if(!img) {img = document.querySelector(`img[src="${light_src}"]`);}
  if(!img) {img = document.querySelector(`img[src="${dark_src}"]`);}

  if(img) {
    // Change the img.src according to the presence or absence of the
    // body element's class.
    function setThemeImage() {
      if(document.body.classList.contains(target_class)) {
        img.src = dark_src;
      } else {
        img.src = light_src;
      }
    }

    // The img.src is modified according to the body class.
    setThemeImage();

    // A ClassWatcher object is created to listen for
    // whenever the body adds or removes the class.
    const classWatcher = new ClassWatcher(
      document.body,
      target_class,
      setThemeImage,
      setThemeImage
    );
  }
}

// -----------------------------------------------------------------------------

// // Pitcher's logo on overview page
// document.addEventListener("DOMContentLoaded", setThemedImage(
//   './assets/doc/images/logo-light.svg',
//   './assets/logo-light.svg',
//   './assets/logo-dark.svg'
// ));

// // Model diagram on database page
// document.addEventListener("DOMContentLoaded", setThemedImage(
//   './images/model-light.svg',
//   './assets/model-light.svg',
//   './assets/model-dark.svg'
// ));
