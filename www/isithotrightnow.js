/* Is it hot right now?
   Code for loading in local weather stats (on page load and on location update)
   James Goldie, Steefan Contractor & Mat Lipson 2017 */

/* on page load: choose a location (for now, Sydney Obs Hill), download
    assets and insert */

console.log('Isithot: JS file loaded');
    
$(function()
{
  default_location = "IDN60901.94768";
  default_path =
    "output/" + default_location + "/";
  
  // fn and obj to track downloaded resources. should probably write a
  // self-contained object for this...
  var loaded_resources = 
  {
    isit_stats: false,
    isit_ts_plot: false,
    isit_density_plot: false
  }
  function resources_loaded()
  {
    if (
      loaded_resources.isit_stats == false |
      loaded_resources.isit_ts_plot == false |
      loaded_resources.isit_density_plot == false)
    {
      return false;
    }
    else
    {
      return true;
    }
  }
  
  // dl stats as json and insert on success.
  // (nb: no error callback available! need to use a timeout below)
  $.getJSON(default_path + "stats.json", function(data)
  {
    $("#isit_answer").text(data.isit_answer);
    $("#isit_comment").text(data.isit_comment);

    $("#isit_current").text(data.isit_current);
    $("#isit_average").text(data.isit_average);
    $("#isit_maximum").text(data.isit_maximum);
    $("#isit_minimum").text(data.isit_minimum);

    loaded_resources.isit_stats = true;

    // enable page if all resources are loaded
    if (resources_loaded())
    // if ($.each(loaded_resources, function(index, value) { return value; }))
    {
      console.log('Isithot: All resources loaded :D');
      $("#detail").attr("style", "display: flex;");
      $("#digdeeper").attr("style", "color: #b22222;");
      $("#digdeeper h3").text("Dig deeper");
    }
  });
  
  // dl *each* image and insert on success
  plots = ["ts_plot", "density_plot"]
  plots.map(function(content)
  {
    var plot_target = $("#isit_" + content + " img");
    console.log('Isithot: Creating callback to load ' + content);
    var plot_building = $("<img>");
    plot_building.on('load', function()
    {
      console.log('Isithot: Inside onload callback for dummy ' + content);
      // when loading img is ready, set it to the target img
      plot_target.attr("src", $(this).attr("src"));

      // enable page if all resources are loaded
      if (resources_loaded())
      {
        console.log('Isithot: All resources loaded :D');
        $("#detail").attr("style", "display: flex;");
        $("#digdeeper").attr("style", "color: #b22222;");
        $("#digdeeper h3").text("Dig deeper");
      }
    });
    // set loading img src to trigger the download
    plot_building.attr("src", default_path + content + ".png");
    console.log('Isithot: Set src attribute for ' + content + '; image ought to be loading now');

    loaded_resources["isit_" + content] = true;
  });

  // apologise if resources aren't all loaded after 10 secs
  setTimeout(function()
  {
    if (!resources_loaded())
    {
      console.log('Isithot: Resources did not load within timeout D:');
      $("#digdeeper h3").text("We're having some trouble downloading the data... 😅");
    }  
  }, 5000);

});