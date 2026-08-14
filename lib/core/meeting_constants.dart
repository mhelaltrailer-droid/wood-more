const int meetingsMaxFileBytes = 5 * 1024 * 1024;

const String meetingFileCallOfMeeting = 'call_of_meeting';
const String meetingFileAgenda = 'meeting_agenda';
const String meetingFileMinutes = 'minutes_of_meeting';
const String meetingFileResolution = 'meeting_resolution';

const List<String> meetingFileTypesInOrder = [
  meetingFileCallOfMeeting,
  meetingFileAgenda,
  meetingFileMinutes,
  meetingFileResolution,
];

const Map<String, String> meetingFileLabels = {
  meetingFileCallOfMeeting: 'Call of Meeting',
  meetingFileAgenda: 'Meeting Agenda',
  meetingFileMinutes: 'Minutes Of Meeting',
  meetingFileResolution: 'Meeting Resolution',
};

String meetingFileLabel(String fileType) =>
    meetingFileLabels[fileType] ?? fileType;

String? previousMeetingFileType(String fileType) {
  final i = meetingFileTypesInOrder.indexOf(fileType);
  return i > 0 ? meetingFileTypesInOrder[i - 1] : null;
}
