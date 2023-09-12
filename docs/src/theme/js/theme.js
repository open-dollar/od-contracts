(function themes() {
  const themeToggleLightButton = document.getElementById("theme-toggle-light");
  const themeToggleDarkButton = document.getElementById("theme-toggle-dark");
  const themeSetLightButton = document.querySelector("button.theme#light");
  const themeSetAyuButton = document.querySelector("button.theme#ayu");

  // react to toggle light button click
  themeToggleLightButton.addEventListener("click", () => {
    themeSetLightButton.click();
  });

  // react to toggle dark button click
  themeToggleDarkButton.addEventListener("click", () => {
    themeSetAyuButton.click();
  });
})();
