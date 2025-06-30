import 'package:flutter/material.dart';
import 'dart:math'; // For random assignment
import 'package:pdf/pdf.dart'; // Import for PDF generation
import 'package:pdf/widgets.dart' as pw; // Import for PDF widgets
import 'package:printing/printing.dart'; // Import for printing/sharing

class GenerateTimetablePage extends StatefulWidget {
  const GenerateTimetablePage({super.key});

  @override
  State<GenerateTimetablePage> createState() => _GenerateTimetablePageState();
}

class _GenerateTimetablePageState extends State<GenerateTimetablePage> {
  final List<String> weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  final Map<String, bool> selecteddays = {};

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _totalLecturesPerWeekController = TextEditingController(); // Renamed for clarity
  final TextEditingController _subjectNameController = TextEditingController();
  final TextEditingController _subjectLectureCountController = TextEditingController();

  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int lectureDuration = 1; // 1 or 2 hours

  // State variable to control visibility of input steps
  int _currentStep = 0; // 0 for initial form, 1 for lecture details, 2 for timetable display

  // Variables for automatic generation
  int? _totalLecturesNeeded; // Total lectures to be scheduled in the week
  int _assignedLecturesCount = 0; // Count of lectures added by subjects
  final List<Map<String, dynamic>> _subjects = []; // List of subjects with name and count

  // Variables to hold generated timetable data
  String _timetableTitle = '';
  List<String> _selectedDisplayDays = [];
  List<TimeOfDay> _timeSlots = [];
  Map<String, Map<String, String>> _timetableData = {}; // day -> timeSlot -> lecture

  @override
  void initState() {
    super.initState();
    for (var day in weekDays) {
      selecteddays[day] = false;
    }
  }

  Future<void> pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  void _navigateToNextStep() {
    // Basic validation for the first step
    if (_titleController.text.isEmpty ||
        startTime == null ||
        endTime == null ||
        selecteddays.values.every((val) => !val)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select at least one day.')),
      );
      return;
    }

    // Generate time slots as they are needed for the next step's validation
    _timeSlots.clear();
    if (startTime != null && endTime != null) {
      int currentHour = startTime!.hour;
      int currentMinute = startTime!.minute;

      while (
      (currentHour < endTime!.hour ||
          (currentHour == endTime!.hour && currentMinute < endTime!.minute))) {
        TimeOfDay slotStartTime = TimeOfDay(hour: currentHour, minute: currentMinute);
        _timeSlots.add(slotStartTime);

        // Advance time by lectureDuration hours
        currentHour += lectureDuration;
      }
    }

    if (_timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be before end time to create slots.')),
      );
      return;
    }


    setState(() {
      _currentStep = 1; // Move to the lecture details step
      _timetableTitle = _titleController.text; // Store title for display
      _selectedDisplayDays = weekDays.where((day) => selecteddays[day]!).toList();
    });
  }

  void _setTotalLecturesPerWeek() {
    final parsedLectures = int.tryParse(_totalLecturesPerWeekController.text);
    if (parsedLectures == null || parsedLectures <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for total lectures.')),
      );
      return;
    }

    setState(() {
      _totalLecturesNeeded = parsedLectures;
      _subjects.clear();
      _assignedLecturesCount = 0;
    });
  }

  void _addSubject() {
    if (_totalLecturesNeeded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set the total lectures per week first.')),
      );
      return;
    }

    final name = _subjectNameController.text.trim();
    final count = int.tryParse(_subjectLectureCountController.text);

    if (name.isEmpty || count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid subject name and lecture count.')),
      );
      return;
    }

    final remainingLectures = _totalLecturesNeeded! - _assignedLecturesCount;
    if (count > remainingLectures) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot add $count lectures. Only $remainingLectures lectures remaining.')),
      );
      return;
    }

    setState(() {
      _subjects.add({'name': name, 'count': count});
      _assignedLecturesCount += count;
      _subjectNameController.clear();
      _subjectLectureCountController.clear();
    });
  }

  void _generateTimetable() {
    if (_totalLecturesNeeded == null || _assignedLecturesCount != _totalLecturesNeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add subjects to match the total lectures per week.')),
      );
      return;
    }
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one subject.')),
      );
      return;
    }

    // Determine max slots per day based on available time slots and selected days
    int maxSlotsPerDay = _timeSlots.length; // Max possible slots in a day based on start/end time and duration
    int totalAvailableSlots = maxSlotsPerDay * _selectedDisplayDays.length;

    if (_totalLecturesNeeded! > totalAvailableSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not enough time slots (${totalAvailableSlots}) to accommodate $_totalLecturesNeeded lectures. Please adjust timings or lecture duration.')),
      );
      return;
    }

    // Initialize timetable data with empty strings
    _timetableData.clear();
    for (var day in _selectedDisplayDays) {
      _timetableData[day] = {};
      for (var slotTime in _timeSlots) {
        String formattedSlot = _formatTimeSlot(slotTime);
        _timetableData[day]![formattedSlot] = 'Free'; // Initially 'Free'
      }
    }

    // Prepare all available slots for random assignment
    List<Map<String, dynamic>> allAvailableSlots = [];
    for (String day in _selectedDisplayDays) {
      for (TimeOfDay slotTime in _timeSlots) {
        String formattedSlot = _formatTimeSlot(slotTime);
        allAvailableSlots.add({'day': day, 'timeSlot': formattedSlot});
      }
    }

    final random = Random();
    allAvailableSlots.shuffle(random); // Shuffle for random placement

    // Assign lectures
    int currentSlotIndex = 0;
    for (var subject in _subjects) {
      String subjectName = subject['name'];
      int count = subject['count'];

      for (int i = 0; i < count; i++) {
        if (currentSlotIndex >= allAvailableSlots.length) {
          // This should ideally not happen if totalAvailableSlots > _totalLecturesNeeded
          // but acts as a safeguard.
          break;
        }

        Map<String, dynamic> slotToFill = allAvailableSlots[currentSlotIndex];
        String day = slotToFill['day'];
        String timeSlot = slotToFill['timeSlot'];

        // Assign the subject to the slot
        _timetableData[day]![timeSlot] = subjectName;
        currentSlotIndex++;
      }
    }

    setState(() {
      _currentStep = 2; // Show the generated timetable
    });
  }

  String _formatTimeSlot(TimeOfDay time) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final String formattedStartTime = localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);

    int endHour = time.hour + lectureDuration;
    int endMinute = time.minute;
    TimeOfDay endTime = TimeOfDay(hour: endHour, minute: endMinute);
    final String formattedEndTime = localizations.formatTimeOfDay(endTime, alwaysUse24HourFormat: false);

    return '$formattedStartTime - $formattedEndTime';
  }

  // --- PDF Generation Logic ---
  Future<void> _generatePdf(BuildContext context) async {
    final pdf = pw.Document();

    // Prepare table headers
    final List<String> tableHeaders = ['Time Slots'];
    tableHeaders.addAll(_selectedDisplayDays);

    // Prepare table data
    final List<List<String>> tableData = [];
    // Add header row
    tableData.add(tableHeaders);

    // Add data rows
    for (var timeSlot in _timeSlots) {
      final List<String> row = [];
      row.add(_formatTimeSlot(timeSlot)); // First cell is the time slot
      String formattedSlot = _formatTimeSlot(timeSlot);
      for (var day in _selectedDisplayDays) {
        row.add(_timetableData[day]![formattedSlot] ?? 'Free');
      }
      tableData.add(row);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _timetableTitle,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: tableData[0], // Use the first row as headers
                data: tableData.sublist(1), // All subsequent rows are data
                border: pw.TableBorder.all(color: PdfColors.black),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                cellStyle: const pw.TextStyle(color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Time Slots column
                  for (int i = 1; i < tableHeaders.length; i++)
                    i: const pw.FlexColumnWidth(1), // Day columns
                },
              ),
            ],
          );
        },
      ),
    );

    // Share or print the PDF
    await Printing.sharePdf(bytes: await pdf.save(), filename: '${_timetableTitle.replaceAll(' ', '_')}_timetable.pdf');
    // You can also use Printing.layoutPdf for direct printing
    // await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  // --- End PDF Generation Logic ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _currentStep == 2
                ? "Your Generated Timetable"
                : (_currentStep == 1 ? "Enter Lecture Details" : "Generate Your Timetable")
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        leading: _currentStep != 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _currentStep--; // Go back to the previous step
              // Clear subject details if going back from step 1 to 0
              if (_currentStep == 0) {
                _totalLecturesNeeded = null;
                _assignedLecturesCount = 0;
                _subjects.clear();
              }
            });
          },
        )
            : null,
      ),
      body: Center(
        child: _currentStep == 0
            ? _buildTimetableInputForm()
            : (_currentStep == 1 ? _buildLectureDetailsForm() : _buildTimetableDisplay()),
      ),
    );
  }

  Widget _buildTimetableInputForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 100),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter General Timetable Information",
            style: TextStyle(
              color: Colors.deepPurple,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: "Enter The Title For The Timetable",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select the Week Days",
                style: TextStyle(color: Colors.black87, fontSize: 15),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select All"),
                  Checkbox(
                    value: selecteddays.values.every((val) => val),
                    onChanged: (value) {
                      setState(() {
                        for (var day in selecteddays.keys) {
                          selecteddays[day] = value!;
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: weekDays.map((day) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: selecteddays[day],
                    onChanged: (value) {
                      setState(() {
                        selecteddays[day] = value!;
                      });
                    },
                  ),
                  Text(day),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Timings for the Day",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => pickTime(context, true),
                    style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        )),
                    child: Text(
                      startTime == null
                          ? "Select Start Time"
                          : "Start: ${startTime!.format(context)}",
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => pickTime(context, false),
                    style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        )),
                    child: Text(
                      endTime == null
                          ? "Select End Time"
                          : "End: ${endTime!.format(context)}",
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Lecture Duration",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Radio<int>(
                    value: 1,
                    groupValue: lectureDuration,
                    onChanged: (value) {
                      setState(() {
                        lectureDuration = value!;
                      });
                    },
                  ),
                  const Text("1 Hour"),
                  const SizedBox(width: 20),
                  Radio<int>(
                    value: 2,
                    groupValue: lectureDuration,
                    onChanged: (value) {
                      setState(() {
                        lectureDuration = value!;
                      });
                    },
                  ),
                  const Text("2 Hours"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _navigateToNextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureDetailsForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 100),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter Lecture Details",
            style: TextStyle(
              color: Colors.deepPurple,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _totalLecturesPerWeekController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Total Lectures Per Week",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _setTotalLecturesPerWeek,
                child: const Text('Set Total'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_totalLecturesNeeded != null) ...[
            Text('Lectures Remaining to Assign: ${_totalLecturesNeeded! - _assignedLecturesCount} / $_totalLecturesNeeded'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _subjectNameController,
                    decoration: const InputDecoration(
                      labelText: "Subject Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _subjectLectureCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Count",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addSubject,
                  child: const Text("Add Subject"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_subjects.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Added Subjects:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._subjects.map((subject) =>
                      Text('${subject['name']}: ${subject['count']} lectures')
                  ).toList(),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_assignedLecturesCount == _totalLecturesNeeded && _subjects.isNotEmpty)
                  ? _generateTimetable
                  : null, // Only enable if all lectures are assigned
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Generate Timetable"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimetableDisplay() {
    if (_selectedDisplayDays.isEmpty || _timeSlots.isEmpty) {
      return const Text("No timetable data to display. Please generate first.");
    }

    List<DataColumn> columns = [
      const DataColumn(label: Text('Time Slots')),
    ];
    for (var day in _selectedDisplayDays) {
      columns.add(DataColumn(label: Text(day)));
    }

    List<DataRow> rows = [];
    for (var timeSlot in _timeSlots) {
      List<DataCell> cells = [
        DataCell(Text(_formatTimeSlot(timeSlot))),
      ];
      String formattedSlot = _formatTimeSlot(timeSlot); // Format once per row
      for (var day in _selectedDisplayDays) {
        cells.add(DataCell(
          Text(_timetableData[day]![formattedSlot] ?? 'Free'),
          onTap: () {
            _editLectureSlot(day, formattedSlot);
          },
        ));
      }
      rows.add(DataRow(cells: cells));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _timetableTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                    return Colors.deepPurple.withOpacity(0.1);
                  }),
              border: TableBorder.all(color: Colors.grey),
              columns: columns,
              rows: rows,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _generatePdf(context), // Call PDF generation here
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Save Timetable as PDF"),
          ),
        ],
      ),
    );
  }

  void _editLectureSlot(String day, String timeSlot) {
    String? currentLecture = _timetableData[day]![timeSlot];
    TextEditingController lectureController = TextEditingController(text: currentLecture == 'Free' ? '' : currentLecture);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Lecture for $day - $timeSlot"),
          content: TextField(
            controller: lectureController,
            decoration: const InputDecoration(labelText: "Lecture Name (leave empty for Free)"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                setState(() {
                  _timetableData[day]![timeSlot] = lectureController.text.isEmpty ? 'Free' : lectureController.text;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalLecturesPerWeekController.dispose();
    _subjectNameController.dispose();
    _subjectLectureCountController.dispose();
    super.dispose();
  }
}