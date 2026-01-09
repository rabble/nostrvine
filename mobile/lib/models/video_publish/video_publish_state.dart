enum VideoPublishState {
  idle,
  initialize,
  preparing,
  uploading,
  retryUpload,
  publishToNostr,
  error,
}
