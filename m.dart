import 'dart:io';

void main(List<String> arguments) {
  Set<int> input1 = stdin.readLineSync()!.split(" ").map(int.parse).toSet();
  Set<int> input2 = stdin.readLineSync()!.split(" ").map(int.parse).toSet();
  Set<int> result = input2.difference(input1);
  result.removeWhere((element) => element > 10);
  print(result);
}
