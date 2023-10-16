(function base() {
  /**
   * Make chapter containers without link clickable
   *
   * You don't always want for a chapter to have a page in itself,
   * in that case, whenever clicked it should trigger the toggle button
   */
  document.querySelectorAll(".chapter li > div").forEach((elm) => {
    elm.addEventListener("click", () => {
      elm.nextElementSibling.click(); // click on toggle
    });
  });
  document.addEventListener('DOMContentLoaded', function () {
    const sidebar = document.getElementById('sidebar');
    if (sidebar && window?.innerWidth < 1280) {
      sidebar.classList.add('hidden');
    }
  });
  document.addEventListener('DOMContentLoaded', function () {
    const sidebarToggle = document.getElementById('sidebar-toggle');
    const sidebar = document.getElementById('sidebar');

    if (sidebarToggle && sidebar) {
      sidebarToggle.addEventListener('click', function () {
        sidebar.classList.toggle('hidden')
      });
    }
  });
})();
