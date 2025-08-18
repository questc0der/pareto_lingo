import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:podcast_search/podcast_search.dart';

class Podcast extends StatefulWidget {
  const Podcast({super.key});

  @override
  State<Podcast> createState() => _Podcasts();
}

class _Podcasts extends State<Podcast> {
  @override
  Widget build(BuildContext context) {
    // podcast();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 18.0),
      child: ListView(
        children: [
          _buildSearchBar(),
          _popularPodcasts(),
          _beginnersPodcast(),
          _intermediatePodcast(),
          _advancedPodcast(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        SearchAnchor(
          builder: (BuildContext context, SearchController controller) {
            return SearchBar(
              controller: controller,
              padding: WidgetStatePropertyAll<EdgeInsets>(
                EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onTap: () => controller.openView(),
              onChanged: (_) => controller.openView(),
              leading: Icon(Icons.search),
            );
          },
          suggestionsBuilder:
              (context, controller) => List<ListTile>.generate(5, (int index) {
                final String item = 'item $index';
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    setState(() {
                      controller.closeView(item);
                    });
                  },
                );
              }),
        ),
      ],
    );
  }

  Future<List<Map<String, String>>> _fetchPodcast() async {
    var search = Search();
    List<Map<String, String>> podcasts = [];
    var results = await search.search(
      'france',
      country: Country.france,
      limit: 100,
    );
    try {
      for (var result in results.items) {
        if (result.feedUrl != null) {
          podcasts.add({
            'image': result.artworkUrl600.toString(),
            'feedUrl': result.feedUrl!,
          });
        } else {
          continue;
        }
      }
    } catch (e) {
      print(e);
    }

    return podcasts;
  }

  Widget _popularPodcasts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Popular Podcast",
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10.0),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            child: FutureBuilder<List<Map<String, String>>>(
              future: _fetchPodcast(),
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.done) {
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width / 1.5,
                        height: MediaQuery.of(context).size.height / 2,
                        child: GestureDetector(
                          onTap: () {
                            context.go(
                              '/podcast_list',
                              extra: snapshot.data![index]['feedUrl'],
                            );
                          },
                          child: Image.network(
                            snapshot.data![index]['image'] ?? "",
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                  );
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
              // child: ListView.separated(
              //   scrollDirection: Axis.horizontal,
              //   itemCount: 5,
              //   itemBuilder: (context, index) {
              //     return Container(
              //       width: MediaQuery.of(context).size.width / 1.5,
              //       height: MediaQuery.of(context).size.height / 2,
              //       decoration: BoxDecoration(
              //         color: Colors.amber,
              //         borderRadius: BorderRadius.circular(24),
              //       ),
              //     );
              //   },
              //   separatorBuilder: (_, __) => const SizedBox(width: 10),
              // ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _beginnersPodcast() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Beginners Podcast",
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10.0),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: MediaQuery.of(context).size.width / 1.5,
                  height: MediaQuery.of(context).size.height / 2,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intermediatePodcast() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Intermediate Podcast",
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10.0),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: MediaQuery.of(context).size.width / 1.5,
                  height: MediaQuery.of(context).size.height / 2,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advancedPodcast() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Advanced Podcast",
              style: TextStyle(
                fontFamily: 'Circular',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 10.0),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: MediaQuery.of(context).size.width / 1.5,
                  height: MediaQuery.of(context).size.height / 2,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(24),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
            ),
          ),
        ],
      ),
    );
  }

  void podcast() async {
    var search = Search();

    var results = await search.search(
      'france',
      country: Country.france,
      limit: 10,
    );

    for (var result in results.items) {
      print('Founded podcast ${result.collectionViewUrl}');
    }

    // var feed = results.items[1].feedUrl;
    // print(feed);
    // if (feed != null) {
    //   var podcast = await Feed.loadFeed(url: feed);

    //   /// Display episode titles.
    //   for (var episode in podcast.episodes) {
    //     print('Episode title: ${episode.contentUrl}');
    //   }
    // }
  }
}
