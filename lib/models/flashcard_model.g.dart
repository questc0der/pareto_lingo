// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final int typeId = 0;

  @override
  Flashcard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Flashcard(
      word: fields[0] as String,
      meaning: fields[1] as String,
      interval: fields[2] as int,
      easeFactor: fields[3] as int,
      dueDate: fields[4] as DateTime?,
      repetitions: fields[5] as int,
      stability: (fields[6] as num?)?.toDouble() ?? 0.0,
      difficulty: (fields[7] as num?)?.toDouble() ?? 5.0,
      lapses: (fields[8] as int?) ?? 0,
      exampleSentence: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Flashcard obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.word)
      ..writeByte(1)
      ..write(obj.meaning)
      ..writeByte(2)
      ..write(obj.interval)
      ..writeByte(3)
      ..write(obj.easeFactor)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.repetitions)
      ..writeByte(6)
      ..write(obj.stability)
      ..writeByte(7)
      ..write(obj.difficulty)
      ..writeByte(8)
      ..write(obj.lapses)
      ..writeByte(9)
      ..write(obj.exampleSentence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
