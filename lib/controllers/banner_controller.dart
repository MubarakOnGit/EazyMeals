import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';

class BannerController extends GetxController {
  final PageController pageController = PageController(initialPage: 1);
  final RxInt currentIndex = 1.obs;
  List<String> banners = [];

  void setBanners(List<String> bannerList) {
    banners = bannerList;
  }

  @override
  void onInit() {
    super.onInit();
    startAutoScroll();
  }

  void startAutoScroll() {
    Timer.periodic(Duration(seconds: 4), (timer) {
      if (currentIndex.value < banners.length - 1) {
        currentIndex.value++;
      } else {
        currentIndex.value = 0;
      }
      pageController.animateToPage(
        currentIndex.value,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
}
