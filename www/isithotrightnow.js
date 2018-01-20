/* Is it hot right now?
   Code for loading in local weather stats (on page load and on location update)
   James Goldie, Steefan Contractor & Mat Lipson 2017 */

/* on page load: choose a location (for now, Sydney Obs Hill), download
    assets and insert */
    
$(function()
{
  var default_station = "066062";
  var base_path = "output/"
  var location_menu_innerpad = 10;
  var location_request_timeout = 5000;
  var geolocation_timeout = 3000;
  var geolocation_done = false;

  /* request_station: hide the details section, download stats and plots
     for a new station and then display them _when they're ready_
     put up an error message if they don't load quickly enough */
  function request_station(station_id)
  {
  
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

    // hide the details section while we update stuff!
    $("#detail").attr("style", "display: none;");
    $("#digdeeper").attr("style", "color: #eee;");
    $("#digdeeper h3").text("Loading...");
    $("#isit_answer").text(". . .");
    $("#isit_comment").text("");
    
    // dl stats as json and insert on success.
    // (nb: no error callback available! need to use a timeout below)
    $.getJSON(base_path + station_id + "/stats.json", function(data)
    {
      $("#isit_answer").text(data.isit_answer);
      $("#isit_comment").text(data.isit_comment);
      $("#isit_maximum").text(data.isit_maximum);
      $("#isit_minimum").text(data.isit_minimum);
      $("#isit_current").text(data.isit_current);
      $("#isit_average").text(data.isit_average);
      $("#isit_name").text(data.isit_name);
      $("#isit_span").text(data.isit_span);

      loaded_resources.isit_stats = true;

      // enable page if all resources are loaded
      if (resources_loaded())
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
      plot_building.attr(
        "src", base_path + station_id + "/" + content + ".png");
      console.log('Isithot: Set src attribute for ' + content + '; image ought to be loading now');

      loaded_resources["isit_" + content] = true;
    });

    // apologise if resources aren't all loaded after 10 secs
    setTimeout(function()
    {
      if (!resources_loaded())
      {
        console.log('Isithot: Resources did not load within timeout D:');
        $("#digdeeper h3").text(
          "We're having some trouble downloading the data...");
      }  
    }, location_request_timeout);
  }

  /* resize_location_menu: resize the location menu according to the
     current selection */
  function resize_location_menu(new_text)
  {
    // resize the dropdown
    $("#current_location_temp_dummyopt").html(new_text);
    $("#current_location").width(
      $("#current_location_temp").width() + location_menu_innerpad);
  }

  /* geo_failure: requests the nearest station id */
  function geo_success(pos_data)
  {
    if (pos_data.country_code != "AU")
    {
      console.warn("User outside Australia; defaulting to Sydney Obs Hill!");
      $("#current_location").val(default_station).trigger("change");
      geolocation_done = true;
    }
    else {
      switch (pos_data.region_code) {
        case 'ACT':
          $("#current_location").val("070351").trigger("change");
          break;
        case 'NSW':
          $("#current_location").val("066062").trigger("change");
          break;
        case 'VIC':
          $("#current_location").val("087031").trigger("change");
          break;
        case 'TAS':
          $("#current_location").val("094029").trigger("change");
          break;
        case 'QLD':
          $("#current_location").val("040842").trigger("change");
          break;
        case 'SA':
          $("#current_location").val("023090").trigger("change");
          break;
        case 'NT':
          $("#current_location").val("014015").trigger("change");
          break;
        case 'WA':
          $("#current_location").val("009021").trigger("change");
          break;
        default:
          console.warn(
            "User region not recognised; " + 
            "defaulting to Sydney Obs Hill!");
          $("#current_location").val(default_station).trigger("change");
      }
      console.log("Geolocation done!");
      geolocation_done = true;
    }
  }

  /* geo_failure: requests the sydney obs hill station id */
  function geo_failure()
  {
    console.warn("Geolocation failed; defaulting to Sydney Obs Hill!");
    $("current_location").val(default_station).trigger("change");
  }

  // = on page load ===========================================================

  // on page load, populate the location menu, then determine default (local)
  // station and request it
  $.getJSON("locations.json", function(data)
  {
    $.each(data, function(index, station) {
      $("#current_location").append(
        '<option value="' + station.id + '">' + station.label + '</option>');
    });

    // now get user location from ip and use to determine a default station
    // (geo_success and geo_failure will update and request the first time)
    if (navigator.geolocation)
    {
      $.get("https://freegeoip.net/json/", geo_success);
    } 
    else
    {
      console.warn("No geolocation available!");
    }

    // default to sydney if geolocation hasn't returned
    setTimeout(function()
    {
      if (!geolocation_done)
      {
        geo_failure();
      }  
    }, geolocation_timeout);
  });

  // = callbacks ==============================================================

  /* on new location selected:
       - update the dropdown menu
       - request new location data */
  $("#current_location").change(function() {
    console.log(this.value);
    resize_location_menu($("option:selected", this).text());
    request_station(this.value);
  });
  
});