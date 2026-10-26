import 'package:intl/intl.dart';

final _won = NumberFormat('#,###', 'ko_KR');

String won(int v) => '${_won.format(v)}원';
String wonSigned(int v) => '${v >= 0 ? '+' : '−'}${_won.format(v.abs())}';
String monthDay(DateTime d) => '${d.month}월 ${d.day}일';
String yearMonth(DateTime d) => '${d.year}년 ${d.month}월';
String clock(DateTime d) => DateFormat('M/d HH:mm').format(d);
