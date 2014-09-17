<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <title></title>
    <script type="text/javascript" src="../Scripts/jquery-1.9.1.min.js"></script>
    <script type="text/javascript" src="../Scripts/d3.v3.min.js"></script>
    <script type="text/javascript">
        //wait for document to load
        var width, height, force, visual, appWebUrl, hostWebUrl, link, node, totalEdgeWeight = 0, totalRank = 0;
        var currentData = null;
        $(document).ready(function () {
            //initalize function to get query parameters for appWebUrl and hostWebUrl
            var getQueryStringParameter = function (urlParameterKey) {
                var params = document.URL.split('?')[1].split('&');
                var strParams = '';
                for (var i = 0; i < params.length; i = i + 1) {
                    var singleParam = params[i].split('=');
                    if (singleParam[0] == urlParameterKey)
                        return singleParam[1];
                }
            }

            //updateVisual function for refreshing the d3 visual
            var updateVisual = function (data) {
                //clear all visuals
                visual.selectAll('circle').remove();
                visual.selectAll('defs').remove();
                visual.selectAll('line').remove();

                //go through children to set radius
                $(data.children).each(function (i, e) {
                    e.radius = Math.sqrt((e.edgeWeight / totalEdgeWeight) * (height * width)) / 4;
                });

                //prepare the data and restart the force
                data.fixed = true;
                data.x = width / 2;
                data.px = width / 2;
                data.y = height / 2;
                data.py = height / 2;
                data.radius = 50;
                currentData = data;
                var nodes = flatten(data);
                var links = d3.layout.tree().links(nodes);

                //restart the force layout and update the links
                force.linkDistance(function (d, i) {
                    var maxRadius = (((width >= height) ? height : width) / 2.5)
                    return Math.random() * maxRadius + (maxRadius * 0.3);})
                    .size([width, height]);
                force.nodes(nodes).links(links).start();
                link = visual.selectAll('line.link').data(links, function (d) { return d.target.id; });

                //enter new links and remove old links
                link.enter().insert('line', '.node')
                    .attr('class', 'link')
                    .attr('stroke', function (d) { return (d.target.type == 'actor') ? '#FFC800' : '#BAD80A'; })
                    .attr('stroke-width', '2px')
                    .attr('x1', function (d) { return d.source.x; })
                    .attr('y1', function (d) { return d.source.y; })
                    .attr('x2', function (d) { return d.target.x; })
                    .attr('y2', function (d) { return d.target.y; });
                link.exit().remove();

                //update the nodes
                node = visual.selectAll('.node')
                    .data(nodes, function (d) { return d.id; });

                //add defs for dynamic patterns
                var def = visual.append('defs');
                node.enter().append('pattern')
                    .attr('id', function (d) { return d.code; })
                    .attr('class', 'imgPattern')
                    .attr('height', 1)
                    .attr('width', 1)
                    .attr('x', '0')
                    .attr('y', '0').append('image')
                    .attr('x', 0)
                    .attr('y', 0)
                    .attr('height', function (d) { return (d.width >= d.height) ? (d.radius * 2) : (d.height / d.width) * (d.radius * 2); })
                    .attr('width', function (d) { return (d.height >= d.width) ? (d.radius * 2) : (d.width / d.height) * (d.radius * 2); })
                    .attr('xlink:href', function (d) { return d.pic + '?' + d.code; })

                //add the nodes
                node.enter().append('circle')
                    .attr('r', function (d) { return d.radius - 2; })
                    .attr('fill', function (d) { return 'url(#' + d.code + ')'; })
                    .attr('stroke', function (d) { return (d.type == 'actor') ? '#FFC800' : '#BAD80A'; })
                    .attr('stroke-width', '3px')
                    .style('cursor', 'default')
                    .attr('class', 'node')
                    .on('click', function (d) {
                        //prevent while dragging
                        if (d3.event.defaultPrevented) return true;

                        //handle event based on node type being actor or object
                        if (d.type == 'actor') {
                            //show spinner
                            $('#divOpacBackground').show();
                            $('#divSpinner').show();

                            //navigate to this actor
                            var entity = { title: d.title, pic: d.pic, text1: d.text1, text2: d.text2, path: d.path, docId: d.docId, actorId: d.actorId };

                            //load children
                            loadUser(entity.actorId, function (children) {
                                entity.children = children;
                                bindUser(entity);
                                $('#divOpacBackground').hide();
                                $('#divSpinner').hide();
                            });
                        }
                        else {
                            //open item in new window
                            window.open(d.path);
                        }
                    })
                    .on('mouseover', function(d, i) {
                        //prevent while dragging
                        if (d3.event.defaultPrevented) return true;
                        if (d.type == 'actor')
                            $('#tooltip').html('<div style="width: 100%;"><div style="width: 20px; float: left; padding-top: 4px;"><img src="../images/actor.png"/></div><div style="width: 270px; float: left;"><h2 class="actor">' + d.title + '</h2></div><div>' + d.text1 + '<br/>' + d.text2 + '</div>');
                        else
                            $('#tooltip').html('<div style="width: 100%;"><div style="width: 20px; float: left; padding-top: 4px;"><img src="../images/object.png"/></div><div style="width: 270px; float: left;"><h2 class="object">' + d.title + '</h2></div><div>' + d.text2 + '<br/>(' + d.text1 + ' Views)</div>');
                        $('#tooltip').css('top', d3.event.clientY);
                        $('#tooltip').css('left', d3.event.clientX + 10);
                        $('#tooltip').show();
                    })
                    .on('mousemove', function(d, i) {
                        //prevent while dragging
                        if (d3.event.defaultPrevented) return true;
                        $('#tooltip').css('top', d3.event.clientY);
                        $('#tooltip').css('left', d3.event.clientX + 10);
                    })
                    .on('mouseout', function (d, i) {
                        //prevent while dragging
                        if (d3.event.defaultPrevented) return true;
                        $('#tooltip').hide();
                    })
                    .call(force.drag);

                //exit old nodes
                node.exit().remove();
            }

            //gets a random 8 character code to tack onto an image to prevent caching (ex: pic.png?a1b2c3d4)
            var getCacheCode = function () {
                var range = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
                var id = '';
                for (i = 0; i < 8; i++)
                    id += range[parseInt(Math.random() * 36)];
                return id;
            }

            //returns a list of all child nodes under the spotlight
            var flatten = function (data) {
                var nodes = [], i = 0;

                function recurse(node) {
                    node.code = getCacheCode();
                    if (node.children) node.size = node.children.reduce(function (p, v) { return p + recurse(v); }, 0);
                    if (!node.id) node.id = ++i;
                    nodes.push(node);
                    return node.size;
                }
                data.size = recurse(data);
                return nodes;
            }

            //function for d3 collide
            var collide = function (node) {
                var r = node.radius + 16,
                    nx1 = node.x - r,
                    nx2 = node.x + r,
                    ny1 = node.y - r,
                    ny2 = node.y + r;
                return function(quad, x1, y1, x2, y2) {
                    if (quad.point && (quad.point !== node)) {
                        var x = node.x - quad.point.x,
                            y = node.y - quad.point.y,
                            l = Math.sqrt(x * x + y * y),
                            r = node.radius + quad.point.radius;
                        if (l < r) {
                            l = (l - r) / l * .5;
                            node.x -= x *= l;
                            node.y -= y *= l;
                            quad.point.x += x;
                            quad.point.y += y;
                        }
                    }
                    return x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1;
                };
            }

            //function for d3 tick
            var tick = function (e) {
                var q = d3.geom.quadtree(currentData), i = 0, n = currentData.length;

                while (++i < n) {
                    q.visit(collide(currentData[i]));
                }

                link.attr('x1', function (d) { return d.source.x; })
                    .attr('y1', function (d) { return d.source.y; })
                    .attr('x2', function (d) { return d.target.x; })
                    .attr('y2', function (d) { return d.target.y; });                                                   

                visual.selectAll("circle")
                    .attr("cx", function (d) { return d.x; })
                    .attr("cy", function (d) { return d.y; });
            }

            //parse a search results row into an object
            var parseObjectResults = function (row) {
                var o = {};
                o.type = 'object';
                $(row.Cells.results).each(function (ii, ee) {
                    if (ee.Key == 'Title')
                        o.title = ee.Value;
                    else if (ee.Key == 'SiteID')
                        o.siteId = ee.Value;
                    else if (ee.Key == 'WebId')
                        o.webId = ee.Value;
                    else if (ee.Key == 'UniqueId')
                        o.uniqueId = ee.Value;
                    else if (ee.Key == 'DocId')
                        o.docId = ee.Value;
                    else if (ee.Key == 'Rank')
                        o.rank = parseFloat(ee.Value);
                    else if (ee.Key == 'Path')
                        o.path = ee.Value;
                    else if (ee.Key == 'DisplayAuthor')
                        o.author = ee.Value;
                    else if (ee.Key == 'FileExtension')
                        o.ext = ee.Value;
                    else if (ee.Key == 'SiteTitle')
                        o.text2 = ee.Value;
                    else if (ee.Key == 'SitePath')
                        o.sitePath = ee.Value;
                    else if (ee.Key == 'Edges') {
                        //get the highest edge weight
                        var edges = JSON.parse(ee.Value);
                        $(edges).each(function (i, e) {
                            var w = parseInt(e.Properties.Weight);
                            if (o.edgeWeight == null || w > o.edgeWeight)
                                o.edgeWeight = w;
                        });
                    }
                    else if (ee.Key == 'ViewCountLifetime') {
                        if (ee.Value == null)
                            o.text1 = '0';
                        else
                            o.text1 = ee.Value;
                    }
                });
                //build an image preview based on uniqueid, siteid, webid, and docid
                o.pic = hostWebUrl + '/_layouts/15/getpreview.ashx?guidFile=' + o.uniqueId + '&guidSite=' + o.siteId + '&guidWeb=' + o.webId + '&docid=' + o.docId + '&ClientType=CodenameOsloWeb&size=small';
                return o;
            }

            //parse a search result row into an actor
            var parseActorResults = function (row) {
                var o = {};
                o.type = 'actor';
                $(row.Cells.results).each(function (ii, ee) {
                    if (ee.Key == 'PreferredName')
                        o.title = ee.Value;
                    else if (ee.Key == 'PictureURL')
                        o.pic = ee.Value;
                    else if (ee.Key == 'JobTitle')
                        o.text1 = ee.Value;
                    else if (ee.Key == 'Department')
                        o.text2 = ee.Value;
                    else if (ee.Key == 'Path')
                        o.path = ee.Value;
                    else if (ee.Key == 'DocId')
                        o.docId = ee.Value;
                    else if (ee.Key == 'Rank')
                        o.rank = parseFloat(ee.Value);
                    else if (ee.Key == 'Edges') {
                        //get the highest edge weight
                        var edges = JSON.parse(ee.Value);
                        o.actorId = edges[0].ActorId;
                        $(edges).each(function (i, e) {
                            var w = parseInt(e.Properties.Weight);
                            if (o.edgeWeight == null || w > o.edgeWeight)
                                o.edgeWeight = w;
                        });
                    }
                });
                return o;
            }

            //load the user by querying the Office Graph for trending content, Colleagues, WorkingWith, and Manager
            var loadUser = function (actorId, callback) {
                var oLoaded = false, aLoaded = false, children = [], workingWithActionID = 1033; //1033 is the public WorkingWith action type
                if (actorId == 'ME')
                    workingWithActionID = 1019; //use the private WorkingWith action type

                //build the object query
                var objectGQL = '', objectGQLcnt = 0;
                if ($('#showTrending').hasClass('selected')) {
                    objectGQLcnt++;
                    objectGQL += "ACTOR(" + actorId + "\\, action\\:1020)"
                }
                if ($('#showModified').hasClass('selected')) {
                    objectGQLcnt++;
                    if (objectGQLcnt > 1)
                        objectGQL += "\\, ";
                    objectGQL += "ACTOR(" + actorId + "\\, action\\:1003)"
                }
                if ($('#showViewed').hasClass('selected') && actorId == 'ME') {
                    objectGQLcnt++;
                    if (objectGQLcnt > 1)
                        objectGQL += "\\, ";
                    objectGQL += "ACTOR(" + actorId + "\\, action\\:1001)"
                }
                if (objectGQLcnt > 1)
                    objectGQL = "OR(" + objectGQL + ")";

                //determine if the object query should be executed
                if (objectGQLcnt == 0)
                    oLoaded = true;
                else {
                    //get objects around the current actor
                    $.ajax({
                        url: appWebUrl + "/_api/search/query?Querytext='*'&Properties='GraphQuery:" + objectGQL + "'&RowLimit=50&SelectProperties='DocId,WebId,UniqueId,SiteID,ViewCountLifetime,Path,DisplayAuthor,FileExtension,Title,SiteTitle,SitePath'",
                        method: 'GET',
                        headers: { "Accept": "application/json; odata=verbose" },
                        success: function (d) {
                            if (d.d.query.PrimaryQueryResult != null &&
                              d.d.query.PrimaryQueryResult.RelevantResults != null &&
                              d.d.query.PrimaryQueryResult.RelevantResults.Table != null &&
                              d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows != null &&
                              d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results != null &&
                              d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results.length > 0) {
                                $(d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results).each(function (i, row) {
                                    children.push(parseObjectResults(row));
                                });
                            }

                            oLoaded = true;
                            if (aLoaded)
                                callback(children);
                        },
                        error: function (err) {
                            showMessage('<div id="private" class="message">Errot calling the Office Graph for objects...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                        }
                    });
                }

                //build the actor query
                var actorGQL = '', actorGQLcnt = 0;
                if ($('#showColleagues').hasClass('selected')) {
                    actorGQLcnt++;
                    actorGQL += "ACTOR(" + actorId + "\\, action\\:1015)"
                }
                if ($('#showWorkingwith').hasClass('selected')) {
                    actorGQLcnt++;
                    if (actorGQLcnt > 1)
                        actorGQL += "\\, ";
                    actorGQL += "ACTOR(" + actorId + "\\, action\\:" + workingWithActionID + ")"
                }
                if ($('#showManager').hasClass('selected')) {
                    actorGQLcnt++;
                    if (actorGQLcnt > 1)
                        actorGQL += "\\, ";
                    actorGQL += "ACTOR(" + actorId + "\\, action\\:1013)"
                }
                if ($('#showDirectreports').hasClass('selected')) {
                    actorGQLcnt++;
                    if (actorGQLcnt > 1)
                        actorGQL += "\\, ";
                    actorGQL += "ACTOR(" + actorId + "\\, action\\:1014)"
                }
                if (actorGQLcnt > 1)
                    actorGQL = "OR(" + actorGQL + ")";

                //determine if the actor query should be executed
                if (actorGQLcnt == 0)
                    aLoaded = true;
                else {
                    //get actors around current actor
                    $.ajax({
                        url: appWebUrl + "/_api/search/query?Querytext='*'&Properties='GraphQuery:" + actorGQL + "'&RowLimit=200&SelectProperties='PictureURL,PreferredName,JobTitle,Path,Department'",
                        method: 'GET',
                        headers: { "Accept": "application/json; odata=verbose" },
                        success: function (d) {
                            if (d.d.query.PrimaryQueryResult != null &&
                               d.d.query.PrimaryQueryResult.RelevantResults != null &&
                               d.d.query.PrimaryQueryResult.RelevantResults.Table != null &&
                               d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows != null &&
                               d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results != null &&
                               d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results.length > 0) {
                                $(d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results).each(function (i, row) {
                                    children.push(parseActorResults(row));
                                });
                            }
                            
                            aLoaded = true;
                            if (oLoaded)
                                callback(children);
                        },
                        error: function (err) {
                            showMessage('<div id="private" class="message">Error calling Office Graph for actors...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                        }
                    });
                }
            }

            var bindUser = function (entity) {
                //go through all children to counts and sum for edgeWeight normalization
                var cntO = 0, totO = 0, cntA = 0, totA = 0;
                $(entity.children).each(function (i, e) {
                    if (e.type == 'actor') {
                        totA += e.edgeWeight;
                        cntA++;
                    }
                    else if (e.type == 'object') {
                        totO += e.edgeWeight;
                        cntO++;
                    }
                });

                //normalize edgeWeight across objects and actors
                totalEdgeWeight = 0;
                $(entity.children).each(function (i, e) {
                    //adjust edgeWeight for actors only
                    if (e.type == 'actor') {
                        //pct of average * average of objects
                        e.edgeWeight = (e.edgeWeight / (totA / cntA)) * (totO / cntO);
                    }
                    totalEdgeWeight += e.edgeWeight
                });

                //load the images so we can get the natural dimensions
                $('#divHide img').remove();
                var hide = $('<div></div>');
                hide.append('<img src="' + entity.pic + '" />');
                $(entity.children).each(function (i, e) {
                    hide.append('<img src="' + e.pic + '" />');
                });
                hide.appendTo('#divHide');
                $('#divHide img').each(function (i, e) {
                    if (i == 0) {
                        entity.width = parseInt(e.naturalWidth);
                        entity.height = parseInt(e.naturalHeight);
                    }
                    else {
                        entity.children[i - 1].width = parseInt(e.naturalWidth);
                        entity.children[i - 1].height = parseInt(e.naturalHeight);

                        if (entity.children[i - 1].width == 0 ||
                            entity.children[i - 1].height == 0) {
                            if (entity.children[i - 1].type == 'actor') {
                                entity.children[i - 1].width = 96;
                                entity.children[i - 1].height = 96;
                                entity.children[i - 1].pic = '../images/nopic.png';
                            }
                            else if (entity.children[i - 1].ext == 'xlsx' || entity.children[i - 1].ext == 'xls') {
                                entity.children[i - 1].width = 300;
                                entity.children[i - 1].height = 300;
                                entity.children[i - 1].pic = '../images/excel.png';
                            }
                            else if (entity.children[i - 1].ext == 'docx' || entity.children[i - 1].ext == 'doc') {
                                entity.children[i - 1].width = 300;
                                entity.children[i - 1].height = 300;
                                entity.children[i - 1].pic = '../images/word.png';
                            }
                            else if (entity.children[i - 1].ext == 'pdf') {
                                entity.children[i - 1].width = 300;
                                entity.children[i - 1].height = 300;
                                entity.children[i - 1].pic = '../images/pdf.png';
                            }
                        }
                    }
                });

                //update the visual
                updateVisual(entity);
            }

            var showMessage = function (html) {
                var curr_html = $('#divMessageBar').html();
                $('#divMessageBar').html(curr_html + html);
            }

            //*************************************
            //Start script for first time load here
            //*************************************
            //initialize the appweb and hostweb URLs
            appWebUrl = decodeURIComponent(getQueryStringParameter('SPAppWebUrl'));
            hostWebUrl = decodeURIComponent(getQueryStringParameter('SPHostUrl'));

            //initialize height and width for canvas
            width = $(window).width();
            height = $(window).height() - 42;

            //wire events for flyout
            $('#divToolboxFlyout').click(function () {
                if ($('#divToolboxWrapper').css('right') == '0px') {
                    $('#divToolboxWrapper').animate({ right: '-290px' }, 250);
                    $('#divToolboxFlyout').removeClass('active');
                }
                else {
                    $('#divToolboxWrapper').animate({ right: '0px' }, 250);
                    $('#divToolboxFlyout').addClass('active');
                }
            });

            //listen for window resize to make responsive
            $(window).resize(function () {
                //recenter visual when browser resizes
                if (currentData != null) {
                    //update width and height
                    width = $(window).width() - 30;
                    height = $(window).height() - 42;

                    //resize visual and force
                    visual.attr('width', width).attr('height', height);
                    force.size([width, height]);

                    //update the visual
                    updateVisual(currentData);
                }
            });

            //wire checkbox change button
            $('.checkbox').click(function (e) {
                var target = $(e.target);
                if (target.hasClass('selected')) {
                    target.removeClass('selected');
                }
                else {
                    target.addClass('selected');
                }
            });

            //apply filters
            $('#btnApplyFilters').click(function () {
                //show spinners
                $('#divOpacBackground').show();
                $('#divSpinner').show();

                //clone the current entity to build new queries
                var entity = { title: currentData.title, pic: currentData.pic, text1: currentData.text1, text2: currentData.text2, path: currentData.path, docId: currentData.docId, actorId: currentData.actorId };

                //load children
                loadUser(entity.actorId, function (children) {
                    entity.children = children;
                    bindUser(entity);
                    $('#divOpacBackground').hide();
                    $('#divSpinner').hide();
                });
            });

            //initialize the d3 objects for force
            force = d3.layout.force()
                    .on('tick', tick)
                    .charge(function (d) { return d._children ? -d.size / 100 : -30; });
            
            //initialize the d3 objects for force
            visual = d3.select('#divCanvas').append('svg')
                    .attr('width', width)
                    .attr('height', height);

            //start by getting the current user's login name so we can query his profile
            //the UserProfile People manager would be faster but requires additional app permissions
            $.ajax({
                url: appWebUrl + '/_api/web/currentUser?$select=LoginName',
                method: 'GET',
                headers: { 'Accept': 'application/json; odata=verbose' },
                success: function (data) {
                    //use the data.d.LoginName to search for the details of the user...again, UserProfile People manager would be more efficient, but requires additional permissions
                    $.ajax({
                        url: appWebUrl + "/_api/search/query?querytext='AccountName:" + encodeURIComponent(data.d.LoginName) + "'&sourceid='B09A7990-05EA-4AF9-81EF-EDFAB16C4E31'",
                        method: 'GET',
                        headers: { 'Accept': 'application/json; odata=verbose' },
                        success: function (d) {
                            var entity = null;
                            //TODO: check for RelevantResults
                            if (d.d.query.PrimaryQueryResult != null &&
                                d.d.query.PrimaryQueryResult.RelevantResults != null &&
                                d.d.query.PrimaryQueryResult.RelevantResults.Table != null &&
                                d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows != null &&
                                d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results != null &&
                                d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results.length > 0) {
                                $(d.d.query.PrimaryQueryResult.RelevantResults.Table.Rows.results).each(function (i, e) {
                                    entity = parseActorResults(e)
                                });

                                if (entity != null) {
                                    //load children for the current user
                                    loadUser('ME', function (children) {
                                        entity.children = children;
                                        entity.actorId = 'ME';
                                        bindUser(entity);
                                        $('#divOpacBackground').hide();
                                        $('#divSpinner').hide();
                                    });
                                }
                                else
                                    showMessage('<div id="private" class="message">Unable to load current user...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                            }
                            else
                                showMessage('<div id="private" class="message">Unable to load current user...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                        },
                        error: function (e) {
                            showMessage('<div id="private" class="message">Unable to load current user...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                        }
                    });
                },
                error: function (err) {
                    showMessage('<div id="private" class="message">Unable to load current user...refresh your browser and try again (<span class="hyperlink" onclick="javascript:$(this).parent().remove();">dismiss</span>).</div>');
                }
            });
        });
    </script>
    <style type="text/css">
        body {
            overflow: hidden;
        }
    </style>
    <link rel="stylesheet" type="text/css" href="../Content/App.css" />
</head>
<body>
    <div id="divOpacBackground"></div>
    <div id="divSpinner">
        <img src="../images/spinner.gif" alt="waiting" />
    </div>
    <div id="divHeader">
        <div id="divHeaderText">Office Graph Explorer</div>

    </div>
    <div id="divMessageBar">
    </div>
    <div id="tooltip"></div>
    <div id="divHide" style="display: none;"></div>
    <div id="divCanvas"></div>
    <div id="divToolboxWrapper">
        <div id="divToolboxFlyout">

        </div>
        <div id="divToolboxContent">
            <h3>About the App</h3>
            <div class="inputContainer">The Office Graph Explorer is a app to graphically navigate through the Office Graph based on the "Actors" that use Office 365</div>
            <h3>Query Options</h3>
            <div class="inputContainer">
                <div class="toolbarItem">
                    <div class="checkbox selected" id="showTrending"></div>
                    <div class="checkboxLabel">Show Trending Content</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox" id="showModified"></div>
                    <div class="checkboxLabel">Show Modified Content</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox" id="showViewed"></div>
                    <div class="checkboxLabel">Show Viewed Content</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox selected" id="showColleagues"></div>
                    <div class="checkboxLabel">Show Colleagues</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox selected" id="showWorkingwith"></div>
                    <div class="checkboxLabel">Show Working With</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox selected" id="showManager"></div>
                    <div class="checkboxLabel">Show Manager</div>
                </div>
                <div class="toolbarItem">
                    <div class="checkbox" id="showDirectreports"></div>
                    <div class="checkboxLabel">Show Direct Reports</div>
                </div>
                <div class="toolbarItem">
                    <div id="btnApplyFilters">
                        Apply
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
