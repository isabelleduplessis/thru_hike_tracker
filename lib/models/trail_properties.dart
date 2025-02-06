enum TrailStructure {
  outAndBack, // if out and back, we don't store direction, only round trip length
  loop, // for loop trails, we store length of loop and assume start point same as farout (indicate that in the ui). if they choose a different start point, we don't track sections?
  pointToPoint,
  other,
}


enum TrailDirection { // referring to where they want mile 0 to start and what direction the miles increase in
  noBo, // Northbound
  soBo, // Southbound
  eaBo, // Eastbound
  weBo, // Westbound
  clockWise, // Clockwise
  counterClockWise, // Counter-clockwise
  forward, // Forward
  backward,; // Backward

// Method to get the opposite direction
  TrailDirection get opposite {
    switch (this) {
      case TrailDirection.noBo:
        return TrailDirection.soBo;
      case TrailDirection.soBo:
        return TrailDirection.noBo;
      case TrailDirection.eaBo:
        return TrailDirection.weBo;
      case TrailDirection.weBo:
        return TrailDirection.eaBo;
      case TrailDirection.clockWise:
        return TrailDirection.counterClockWise;
      case TrailDirection.counterClockWise:
        return TrailDirection.clockWise;
      case TrailDirection.forward:
        return TrailDirection.backward;
      case TrailDirection.backward:
        return TrailDirection.forward;
    }
  }
}