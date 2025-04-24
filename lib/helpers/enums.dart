enum PathFindingState {
  idle('idle'), ready('ready'), finding('finding'), finished('finished');
  final String value;
  const PathFindingState(this.value);
}