class MarkerRow {
  String userId = '';
  String markerName;
  String fileNumber;
  String role;
  String fileRef = '';
  String subject = '';
  String shift = '';
  String location = '';
  String gender;

  MarkerRow({
    required this.markerName,
    required this.fileNumber,
    required this.role,
    required this.gender,
  });
}
