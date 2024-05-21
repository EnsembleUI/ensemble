function getObjectByName(n){

}

function devicesTrigger(e){
    console.log(e)
}
function removeChart(id) {
    var e = document.querySelectorAll('[id='+id+']');
    if ( e && e.length > 0 ) {
        for (var i = e.length-1; i >= 0 ; i--) {
            e[i].remove();
        }
    }
}
function getDevicesElement(devicesInfo){
  const ul = document.createElement("ul")

  devicesInfo.forEach(el=>{
    const li = document.createElement("li")
    li.classList.add(el.connection.line)
    li.classList.add(el.connection.color)
    li.setAttribute("data-name", el.name)


    li.innerHTML = `
    <div class="list-icon">
      <span><i class="fas ${el.connection.icon}"></i></span>
    </div>
    <div class="list-content">
      <div class="text-left"><span>${el.speed}</span></div>
      <div class="line"></div>
      <div class="text-right" onclick="devicesTrigger('${el.name}')"><p>${el.name}</p></div>
    </div>
    `
    ul.appendChild(li)
  })

  return ul
}

function getIcon(icon, color){
    switch(icon){
        case "wifi":
            return `<i class='fa-solid fa-wifi ${color}'></i>`
    }
}

function buildElement(parentId,info){
  const mainGateway = info.mainGateway
  const childGateways = info.childGateways


  const div = document.createElement("div")
  div.classList.add("wrapper")
  div.innerHTML = `
         <div class="tab-header">
            <h4>Topologie</h4>
         </div>
         <div class="tab">
            <!-- Tab bottom content -->
            <div class="tab-top-content">
                <span>${mainGateway.name}</span>
                <p>${mainGateway.ip}</p>
            </div>
            <button class="tablinks active">
                <div class="tab-icon-container">
                    <img class="tab-active-img" src="images/bg.svg" alt="service-img"/>
                    <img class="tab-main-img" src="images/${mainGateway.mainIcon}" alt="service-img"/>
                    <span class="tab-status-icon">${getIcon(mainGateway.statusIcon, mainGateway.statusIconColor)}</span>
                </div>
            </button>

            <!-- Tab bottom content -->
            <div class="tab-bottom-content">
               <p><span>${mainGateway.deviceCount}</span> verbonden apparaten</p>
               <span class="tab-element">Wifinaam: ${mainGateway.wifiName}</span>
               <span class="tab-element">${mainGateway.guestWifiName}</span>
            </div>
         </div>
      
         <div id="Paris" class="tabcontent">            
           

         
         </div>`

         childGateways.forEach(el=>{
            let devicesInfoEl = ""
            if(el.devices){
                devicesInfoEl = getDevicesElement(el.devices)
            }

            const div1 = document.createElement("div")
            div1.classList.add("tab-content-items")
            div1.classList.add(el.status)
            div1.innerHTML = `
                ${el.status === "error" ? `
              <div class="card-alert">
                <span class="info-icon"><i class="fa-solid fa-info"></i></span>
                <p>${el.errorMessage}</p>
                <span class="close-icon"><i class="fa-solid fa-xmark"></i></span>
              </div>` : ""}

                <div class="left-content-item">
                    <div class="single-image">
                    ${el.status != "error" ? `        
                        <div class="top-icon ${el.connection.line} ${el.connection.color}">
                            <div class="top-icon-inner">
                                <i class="fa-solid ${el.connection.icon}"></i>
                            </div>
                            <p class="icon-line"></p>
                        </div>
                        ` : ""}
                        <div class="single-image-icon">
                            <img src="images/${el.mainIcon}" alt="service-img"/>
                            ${el.status != "error" ? `        
                                <span>${getIcon(el.statusIcon, el.statusIconColor)}</span>
                                ` : ""}
                        </div>
                    </div>
                    <div class="left-single-content">
                        <h4>${el.name}</h4>
                        <p>${el.speed}</p>
                        ${el.status != "error" ? `
                        <span>${el.devices.length} getcoppelde appration</span>
                    ` : ""}
                    </div>
                </div>
                ${devicesInfoEl != "" ? `
                    <div class="tab-content-right">
                        <div class="tab-right-list">
                            ${devicesInfoEl.outerHTML}
                        </div>
                    </div>
                ` : ""}`
            div.querySelector("#Paris").appendChild(div1)
          })

          if(info.devices.length > 0){
            const div1 = document.createElement("div")
            div1.classList.add("card-one")
            div1.classList.add("card-three")
            devicesInfoEl = getDevicesElement(info.devices)

            div1.innerHTML = `
               <div class="tab-content-right">
                  <p class="card-title">${info.devices.length} verbonden apparaten </p>
                  <div class="tab-content-right">
                        <div class="tab-right-list">
                           ${devicesInfoEl.outerHTML}
                        </div>
                    </div>
               </div>`

            div.querySelector("#Paris").appendChild(div1)
          }

  document.querySelector('#'+parentId).appendChild(div)
  activateEvent()
}

function activateEvent(){
    var obj = document.querySelector(".close-icon");
    if ( obj ) {
      obj.addEventListener("click", (e)=>{
        e.target.parentElement.parentElement.remove()
      });
  }
}
