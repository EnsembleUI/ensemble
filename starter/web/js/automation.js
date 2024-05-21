 //following functions will work only when testmode=true in the query parm
 //that's when we run the semantic framework
 //either ariaLable, type is required, both could be sent as well or narrow down the results
function findElements(ariaLabel, role, contains = false) {
  const flutterView = document.querySelector('flutter-view');
  if (!flutterView) {
    return null;
  }

  // Initialize an empty selector string
  let selector = '';

  // Append aria-label to the selector if it's provided and not empty
  if (ariaLabel) {
    if (contains) {
      // Use the CSS attribute selector with *= operator to check if aria-label contains the given value
      selector += `[aria-label*="${ariaLabel}"]`;
    } else {
      // Use the CSS attribute selector for exact match
      selector += `[aria-label="${ariaLabel}"]`;
    }
  }

  // Append role to the selector if it's provided and not empty
  if (role) {
    selector += `[role="${role}"]`;
  }

  // If neither ariaLabel nor role are provided, return null or an empty NodeList
  // depending on your use case. Here, we choose to return all children as a fallback.
  if (!ariaLabel && !role) {
    return flutterView.querySelectorAll('*');
  }

  return flutterView.querySelectorAll(selector);
}

  function findFirstElement(ariaLabel,role, contains = false) {
    const elements = findElements(ariaLabel,role,contains);
    return elements.length > 0 ? elements[0] : null;
  }