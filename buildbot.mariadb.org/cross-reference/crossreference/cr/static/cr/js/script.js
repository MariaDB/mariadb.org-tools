function DocReady(fn) {
  // see if DOM is already available
  if (document.readyState === "complete" || document.readyState === "interactive") {
    // call on next available tick
    setTimeout(fn, 1);
  } else {
    document.addEventListener("DOMContentLoaded", fn);
  }
}

function attachEventOnExpandableRow() {
  var expandableRow = document.getElementsByClassName("expandable");
  var i;

  for (i = 0; i < expandableRow.length; i++) {
    expandableRow[i].addEventListener("click", function() {
      let rowColumns = this.children;
      let lastColumn = rowColumns[rowColumns.length-1];
      let infoRow = this.nextElementSibling;

      this.classList.toggle("active");

      if (infoRow.style.display === "table-row") {
        infoRow.style.display = "none";
      } else {
        infoRow.style.display = "table-row";
      }
    });
  }
}

function scrollFunction(topArrow) {
// When the user scrolls down 20px from the top of the document, show the button
  if (document.body.scrollTop > 20 || document.documentElement.scrollTop > 20) {
    topArrow.style.display = "block";
  } else {
    topArrow.style.display = "none";
  }
}

function attachEventOnScrollArrow(topArrow) {
  topArrow.addEventListener("click", function() {
    document.body.scrollTop = 0;
    document.documentElement.scrollTop = 0;
  });
}

// When the user clicks on the button, scroll to the top of the document
function topFunction() {
  document.body.scrollTop = 0;
  document.documentElement.scrollTop = 0;
}

DocReady(function() {
  var topArrow = document.getElementById("top-arrow");
  window.onscroll = function() {scrollFunction(topArrow)};
  attachEventOnScrollArrow(topArrow);
  attachEventOnExpandableRow();
});
