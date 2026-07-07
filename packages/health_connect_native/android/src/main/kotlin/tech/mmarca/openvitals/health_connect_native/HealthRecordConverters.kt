@file:Suppress("UNCHECKED_CAST")

package tech.mmarca.openvitals.health_connect_native

import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalBodyTemperatureRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.BodyWaterMassRecord
import androidx.health.connect.client.records.BoneMassRecord
import androidx.health.connect.client.records.CervicalMucusRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ElevationGainedRecord
import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.IntermenstrualBleedingRecord
import androidx.health.connect.client.records.LeanBodyMassRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MenstruationPeriodRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.OvulationTestRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SexualActivityRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsCadenceRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.WheelchairPushesRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.BloodGlucose
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.Pressure
import androidx.health.connect.client.units.Temperature
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Velocity
import androidx.health.connect.client.units.Volume
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneOffset
import kotlin.reflect.KClass

/**
 * Converts between the canonical record JSON schema (documented in
 * `lib/health_connect_native.dart`) and AndroidX Health Connect [Record]s.
 *
 * Times are epoch milliseconds (UTC); zone offsets are seconds east of UTC.
 * Units are canonical: meters, kilograms, kilocalories, liters, celsius,
 * millimoles/L, meters/second, watts, bpm, milliseconds.
 */
internal object HealthRecordConverters {

    /** Maps a schema record-type string to the AndroidX record [KClass]. */
    fun recordClassFor(recordType: String): KClass<out Record>? = when (recordType) {
        "Steps" -> StepsRecord::class
        "Distance" -> DistanceRecord::class
        "ActiveCaloriesBurned" -> ActiveCaloriesBurnedRecord::class
        "TotalCaloriesBurned" -> TotalCaloriesBurnedRecord::class
        "FloorsClimbed" -> FloorsClimbedRecord::class
        "ElevationGained" -> ElevationGainedRecord::class
        "WheelchairPushes" -> WheelchairPushesRecord::class
        "ExerciseSession" -> ExerciseSessionRecord::class
        "Speed" -> SpeedRecord::class
        "StepsCadence" -> StepsCadenceRecord::class
        "CyclingPedalingCadence" -> CyclingPedalingCadenceRecord::class
        "Power" -> PowerRecord::class
        "Sleep" -> SleepSessionRecord::class
        "HeartRate" -> HeartRateRecord::class
        "RestingHeartRate" -> RestingHeartRateRecord::class
        "HeartRateVariabilityRmssd" -> HeartRateVariabilityRmssdRecord::class
        "Weight" -> WeightRecord::class
        "Height" -> HeightRecord::class
        "BodyFat" -> BodyFatRecord::class
        "LeanBodyMass" -> LeanBodyMassRecord::class
        "BoneMass" -> BoneMassRecord::class
        "BodyWaterMass" -> BodyWaterMassRecord::class
        "BasalMetabolicRate" -> BasalMetabolicRateRecord::class
        "Hydration" -> HydrationRecord::class
        "Nutrition" -> NutritionRecord::class
        "MindfulnessSession" -> MindfulnessSessionRecord::class
        "MenstruationFlow" -> MenstruationFlowRecord::class
        "MenstruationPeriod" -> MenstruationPeriodRecord::class
        "OvulationTest" -> OvulationTestRecord::class
        "CervicalMucus" -> CervicalMucusRecord::class
        "BasalBodyTemperature" -> BasalBodyTemperatureRecord::class
        "IntermenstrualBleeding" -> IntermenstrualBleedingRecord::class
        "SexualActivity" -> SexualActivityRecord::class
        "BloodPressure" -> BloodPressureRecord::class
        "OxygenSaturation" -> OxygenSaturationRecord::class
        "RespiratoryRate" -> RespiratoryRateRecord::class
        "BodyTemperature" -> BodyTemperatureRecord::class
        "SkinTemperature" -> SkinTemperatureRecord::class
        "BloodGlucose" -> BloodGlucoseRecord::class
        "Vo2Max" -> Vo2MaxRecord::class
        else -> null
    }

    // -------------------------------------------------------------------------
    // Read: Record -> JSON string
    // -------------------------------------------------------------------------

    fun recordToJson(record: Record): String = recordToJsonObject(record).toString()

    private fun recordToJsonObject(record: Record): JSONObject {
        val o = JSONObject()
        when (record) {
            is StepsRecord -> {
                o.put("recordType", "Steps")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("count", record.count)
            }
            is DistanceRecord -> {
                o.put("recordType", "Distance")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("distanceMeters", record.distance.inMeters)
            }
            is ActiveCaloriesBurnedRecord -> {
                o.put("recordType", "ActiveCaloriesBurned")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("energyKcal", record.energy.inKilocalories)
            }
            is TotalCaloriesBurnedRecord -> {
                o.put("recordType", "TotalCaloriesBurned")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("energyKcal", record.energy.inKilocalories)
            }
            is FloorsClimbedRecord -> {
                o.put("recordType", "FloorsClimbed")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("floors", record.floors)
            }
            is ElevationGainedRecord -> {
                o.put("recordType", "ElevationGained")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("elevationMeters", record.elevation.inMeters)
            }
            is WheelchairPushesRecord -> {
                o.put("recordType", "WheelchairPushes")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("count", record.count)
            }
            is ExerciseSessionRecord -> {
                o.put("recordType", "ExerciseSession")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("exerciseType", record.exerciseType)
                record.title?.let { o.put("title", it) }
                record.notes?.let { o.put("notes", it) }
                record.plannedExerciseSessionId?.let { o.put("plannedExerciseSessionId", it) }
                val segments = JSONArray()
                for (segment in record.segments) {
                    segments.put(
                        JSONObject()
                            .put("startEpochMs", segment.startTime.toEpochMilli())
                            .put("endEpochMs", segment.endTime.toEpochMilli())
                            .put("segmentType", segment.segmentType)
                            .put("repetitions", segment.repetitions),
                    )
                }
                o.put("segments", segments)
                val laps = JSONArray()
                for (lap in record.laps) {
                    val lapJson = JSONObject()
                        .put("startEpochMs", lap.startTime.toEpochMilli())
                        .put("endEpochMs", lap.endTime.toEpochMilli())
                    lap.length?.let { lapJson.put("lengthMeters", it.inMeters) }
                    laps.put(lapJson)
                }
                o.put("laps", laps)
                val routeResult = record.exerciseRouteResult
                if (routeResult is ExerciseRouteResult.Data) {
                    val points = JSONArray()
                    for (point in routeResult.exerciseRoute.route) {
                        val p = JSONObject()
                            .put("timeEpochMs", point.time.toEpochMilli())
                            .put("latitude", point.latitude)
                            .put("longitude", point.longitude)
                        point.altitude?.let { p.put("altitudeMeters", it.inMeters) }
                        point.horizontalAccuracy?.let { p.put("horizontalAccuracyMeters", it.inMeters) }
                        point.verticalAccuracy?.let { p.put("verticalAccuracyMeters", it.inMeters) }
                        points.put(p)
                    }
                    o.put("route", JSONObject().put("points", points))
                }
            }
            is SpeedRecord -> {
                o.put("recordType", "Speed")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                val samples = JSONArray()
                for (sample in record.samples) {
                    samples.put(
                        JSONObject()
                            .put("timeEpochMs", sample.time.toEpochMilli())
                            .put("metersPerSecond", sample.speed.inMetersPerSecond),
                    )
                }
                o.put("samples", samples)
            }
            is StepsCadenceRecord -> {
                o.put("recordType", "StepsCadence")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                val samples = JSONArray()
                for (sample in record.samples) {
                    samples.put(
                        JSONObject()
                            .put("timeEpochMs", sample.time.toEpochMilli())
                            .put("rate", sample.rate),
                    )
                }
                o.put("samples", samples)
            }
            is CyclingPedalingCadenceRecord -> {
                o.put("recordType", "CyclingPedalingCadence")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                val samples = JSONArray()
                for (sample in record.samples) {
                    samples.put(
                        JSONObject()
                            .put("timeEpochMs", sample.time.toEpochMilli())
                            .put("revolutionsPerMinute", sample.revolutionsPerMinute),
                    )
                }
                o.put("samples", samples)
            }
            is PowerRecord -> {
                o.put("recordType", "Power")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                val samples = JSONArray()
                for (sample in record.samples) {
                    samples.put(
                        JSONObject()
                            .put("timeEpochMs", sample.time.toEpochMilli())
                            .put("watts", sample.power.inWatts),
                    )
                }
                o.put("samples", samples)
            }
            is SleepSessionRecord -> {
                o.put("recordType", "Sleep")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                record.title?.let { o.put("title", it) }
                record.notes?.let { o.put("notes", it) }
                val stages = JSONArray()
                for (stage in record.stages) {
                    stages.put(
                        JSONObject()
                            .put("startEpochMs", stage.startTime.toEpochMilli())
                            .put("endEpochMs", stage.endTime.toEpochMilli())
                            .put("stage", stage.stage),
                    )
                }
                o.put("stages", stages)
            }
            is HeartRateRecord -> {
                o.put("recordType", "HeartRate")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                val samples = JSONArray()
                for (sample in record.samples) {
                    samples.put(
                        JSONObject()
                            .put("timeEpochMs", sample.time.toEpochMilli())
                            .put("bpm", sample.beatsPerMinute),
                    )
                }
                o.put("samples", samples)
            }
            is RestingHeartRateRecord -> {
                o.put("recordType", "RestingHeartRate")
                putInstant(o, record.time, record.zoneOffset)
                o.put("bpm", record.beatsPerMinute)
            }
            is HeartRateVariabilityRmssdRecord -> {
                o.put("recordType", "HeartRateVariabilityRmssd")
                putInstant(o, record.time, record.zoneOffset)
                o.put("rmssdMs", record.heartRateVariabilityMillis)
            }
            is WeightRecord -> {
                o.put("recordType", "Weight")
                putInstant(o, record.time, record.zoneOffset)
                o.put("weightKg", record.weight.inKilograms)
            }
            is HeightRecord -> {
                o.put("recordType", "Height")
                putInstant(o, record.time, record.zoneOffset)
                o.put("heightMeters", record.height.inMeters)
            }
            is BodyFatRecord -> {
                o.put("recordType", "BodyFat")
                putInstant(o, record.time, record.zoneOffset)
                o.put("percentage", record.percentage.value)
            }
            is LeanBodyMassRecord -> {
                o.put("recordType", "LeanBodyMass")
                putInstant(o, record.time, record.zoneOffset)
                o.put("massKg", record.mass.inKilograms)
            }
            is BoneMassRecord -> {
                o.put("recordType", "BoneMass")
                putInstant(o, record.time, record.zoneOffset)
                o.put("massKg", record.mass.inKilograms)
            }
            is BodyWaterMassRecord -> {
                o.put("recordType", "BodyWaterMass")
                putInstant(o, record.time, record.zoneOffset)
                o.put("massKg", record.mass.inKilograms)
            }
            is BasalMetabolicRateRecord -> {
                o.put("recordType", "BasalMetabolicRate")
                putInstant(o, record.time, record.zoneOffset)
                o.put("kcalPerDay", record.basalMetabolicRate.inKilocaloriesPerDay)
            }
            is HydrationRecord -> {
                o.put("recordType", "Hydration")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("volumeLiters", record.volume.inLiters)
            }
            is NutritionRecord -> {
                o.put("recordType", "Nutrition")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                record.name?.let { o.put("name", it) }
                o.put("mealType", record.mealType)
                record.energy?.let { o.put("energyKcal", it.inKilocalories) }
                record.energyFromFat?.let { o.put("energyFromFatKcal", it.inKilocalories) }
                for ((key, getter) in NUTRITION_MASS_FIELDS) {
                    getter(record)?.let { o.put(key, it.inGrams) }
                }
            }
            is MindfulnessSessionRecord -> {
                o.put("recordType", "MindfulnessSession")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                o.put("mindfulnessSessionType", record.mindfulnessSessionType)
                record.title?.let { o.put("title", it) }
                record.notes?.let { o.put("notes", it) }
            }
            is MenstruationFlowRecord -> {
                o.put("recordType", "MenstruationFlow")
                putInstant(o, record.time, record.zoneOffset)
                o.put("flow", record.flow)
            }
            is MenstruationPeriodRecord -> {
                o.put("recordType", "MenstruationPeriod")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
            }
            is OvulationTestRecord -> {
                o.put("recordType", "OvulationTest")
                putInstant(o, record.time, record.zoneOffset)
                o.put("result", record.result)
            }
            is CervicalMucusRecord -> {
                o.put("recordType", "CervicalMucus")
                putInstant(o, record.time, record.zoneOffset)
                o.put("appearance", record.appearance)
                o.put("sensation", record.sensation)
            }
            is BasalBodyTemperatureRecord -> {
                o.put("recordType", "BasalBodyTemperature")
                putInstant(o, record.time, record.zoneOffset)
                o.put("temperatureCelsius", record.temperature.inCelsius)
                o.put("measurementLocation", record.measurementLocation)
            }
            is IntermenstrualBleedingRecord -> {
                o.put("recordType", "IntermenstrualBleeding")
                putInstant(o, record.time, record.zoneOffset)
            }
            is SexualActivityRecord -> {
                o.put("recordType", "SexualActivity")
                putInstant(o, record.time, record.zoneOffset)
                o.put("protectionUsed", record.protectionUsed)
            }
            is BloodPressureRecord -> {
                o.put("recordType", "BloodPressure")
                putInstant(o, record.time, record.zoneOffset)
                o.put("systolicMmHg", record.systolic.inMillimetersOfMercury)
                o.put("diastolicMmHg", record.diastolic.inMillimetersOfMercury)
                o.put("bodyPosition", record.bodyPosition)
                o.put("measurementLocation", record.measurementLocation)
            }
            is OxygenSaturationRecord -> {
                o.put("recordType", "OxygenSaturation")
                putInstant(o, record.time, record.zoneOffset)
                o.put("percentage", record.percentage.value)
            }
            is RespiratoryRateRecord -> {
                o.put("recordType", "RespiratoryRate")
                putInstant(o, record.time, record.zoneOffset)
                o.put("rate", record.rate)
            }
            is BodyTemperatureRecord -> {
                o.put("recordType", "BodyTemperature")
                putInstant(o, record.time, record.zoneOffset)
                o.put("temperatureCelsius", record.temperature.inCelsius)
                o.put("measurementLocation", record.measurementLocation)
            }
            is SkinTemperatureRecord -> {
                o.put("recordType", "SkinTemperature")
                putInterval(o, record.startTime, record.endTime, record.startZoneOffset, record.endZoneOffset)
                record.baseline?.let { o.put("baselineCelsius", it.inCelsius) }
                o.put("measurementLocation", record.measurementLocation)
                val deltas = JSONArray()
                for (delta in record.deltas) {
                    deltas.put(
                        JSONObject()
                            .put("timeEpochMs", delta.time.toEpochMilli())
                            .put("deltaCelsius", delta.delta.inCelsius),
                    )
                }
                o.put("deltas", deltas)
            }
            is BloodGlucoseRecord -> {
                o.put("recordType", "BloodGlucose")
                putInstant(o, record.time, record.zoneOffset)
                o.put("levelMmolL", record.level.inMillimolesPerLiter)
                o.put("specimenSource", record.specimenSource)
                o.put("mealType", record.mealType)
                o.put("relationToMeal", record.relationToMeal)
            }
            is Vo2MaxRecord -> {
                o.put("recordType", "Vo2Max")
                putInstant(o, record.time, record.zoneOffset)
                o.put("vo2MillilitersPerMinuteKilogram", record.vo2MillilitersPerMinuteKilogram)
                o.put("measurementMethod", record.measurementMethod)
            }
            else -> {
                o.put("recordType", record.javaClass.simpleName)
            }
        }
        putCommonMetadata(o, record.metadata)
        return o
    }

    private fun putCommonMetadata(o: JSONObject, m: Metadata) {
        o.put("id", m.id)
        m.clientRecordId?.let { o.put("clientRecordId", it) }
        o.put("clientRecordVersion", m.clientRecordVersion)
        o.put("dataOriginPackage", m.dataOrigin.packageName)
        o.put("lastModifiedEpochMs", m.lastModifiedTime.toEpochMilli())
        o.put("recordingMethod", m.recordingMethod)
        m.device?.let { device ->
            val d = JSONObject().put("type", device.type)
            device.manufacturer?.let { d.put("manufacturer", it) }
            device.model?.let { d.put("model", it) }
            o.put("device", d)
        }
    }

    private fun putInterval(
        o: JSONObject,
        startTime: Instant,
        endTime: Instant,
        startZoneOffset: ZoneOffset?,
        endZoneOffset: ZoneOffset?,
    ) {
        o.put("startEpochMs", startTime.toEpochMilli())
        o.put("endEpochMs", endTime.toEpochMilli())
        startZoneOffset?.let { o.put("startZoneOffsetSeconds", it.totalSeconds) }
        endZoneOffset?.let { o.put("endZoneOffsetSeconds", it.totalSeconds) }
    }

    private fun putInstant(o: JSONObject, time: Instant, zoneOffset: ZoneOffset?) {
        o.put("timeEpochMs", time.toEpochMilli())
        zoneOffset?.let { o.put("zoneOffsetSeconds", it.totalSeconds) }
    }

    // -------------------------------------------------------------------------
    // Write: JSON -> Record
    // -------------------------------------------------------------------------

    /** Builds an AndroidX record from a JSON object, or throws on unknown/invalid input. */
    fun jsonToRecord(json: JSONObject): Record {
        val recordType = json.getString("recordType")
        val metadata = buildMetadata(json)
        return when (recordType) {
            "Steps" -> StepsRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                count = json.getLong("count"),
                metadata = metadata,
            )
            "Distance" -> DistanceRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                distance = Length.meters(json.getDouble("distanceMeters")),
                metadata = metadata,
            )
            "ActiveCaloriesBurned" -> ActiveCaloriesBurnedRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                energy = Energy.kilocalories(json.getDouble("energyKcal")),
                metadata = metadata,
            )
            "TotalCaloriesBurned" -> TotalCaloriesBurnedRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                energy = Energy.kilocalories(json.getDouble("energyKcal")),
                metadata = metadata,
            )
            "FloorsClimbed" -> FloorsClimbedRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                floors = json.getDouble("floors"),
                metadata = metadata,
            )
            "ElevationGained" -> ElevationGainedRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                elevation = Length.meters(json.getDouble("elevationMeters")),
                metadata = metadata,
            )
            "WheelchairPushes" -> WheelchairPushesRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                count = json.getLong("count"),
                metadata = metadata,
            )
            "ExerciseSession" -> buildExerciseSession(json, metadata)
            "Speed" -> SpeedRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                samples = json.samples("samples") { s ->
                    SpeedRecord.Sample(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        speed = Velocity.metersPerSecond(s.getDouble("metersPerSecond")),
                    )
                },
                metadata = metadata,
            )
            "StepsCadence" -> StepsCadenceRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                samples = json.samples("samples") { s ->
                    StepsCadenceRecord.Sample(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        rate = s.getDouble("rate"),
                    )
                },
                metadata = metadata,
            )
            "CyclingPedalingCadence" -> CyclingPedalingCadenceRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                samples = json.samples("samples") { s ->
                    CyclingPedalingCadenceRecord.Sample(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        revolutionsPerMinute = s.getDouble("revolutionsPerMinute"),
                    )
                },
                metadata = metadata,
            )
            "Power" -> PowerRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                samples = json.samples("samples") { s ->
                    PowerRecord.Sample(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        power = Power.watts(s.getDouble("watts")),
                    )
                },
                metadata = metadata,
            )
            "Sleep" -> SleepSessionRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                metadata = metadata,
                title = json.stringOrNull("title"),
                notes = json.stringOrNull("notes"),
                stages = json.samples("stages") { s ->
                    SleepSessionRecord.Stage(
                        startTime = Instant.ofEpochMilli(s.getLong("startEpochMs")),
                        endTime = Instant.ofEpochMilli(s.getLong("endEpochMs")),
                        stage = s.getInt("stage"),
                    )
                },
            )
            "HeartRate" -> HeartRateRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                samples = json.samples("samples") { s ->
                    HeartRateRecord.Sample(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        beatsPerMinute = s.getLong("bpm"),
                    )
                },
                metadata = metadata,
            )
            "RestingHeartRate" -> RestingHeartRateRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                beatsPerMinute = json.getLong("bpm"),
                metadata = metadata,
            )
            "HeartRateVariabilityRmssd" -> HeartRateVariabilityRmssdRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                heartRateVariabilityMillis = json.getDouble("rmssdMs"),
                metadata = metadata,
            )
            "Weight" -> WeightRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                weight = Mass.kilograms(json.getDouble("weightKg")),
                metadata = metadata,
            )
            "Height" -> HeightRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                height = Length.meters(json.getDouble("heightMeters")),
                metadata = metadata,
            )
            "BodyFat" -> BodyFatRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                percentage = Percentage(json.getDouble("percentage")),
                metadata = metadata,
            )
            "LeanBodyMass" -> LeanBodyMassRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                mass = Mass.kilograms(json.getDouble("massKg")),
                metadata = metadata,
            )
            "BoneMass" -> BoneMassRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                mass = Mass.kilograms(json.getDouble("massKg")),
                metadata = metadata,
            )
            "BodyWaterMass" -> BodyWaterMassRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                mass = Mass.kilograms(json.getDouble("massKg")),
                metadata = metadata,
            )
            "BasalMetabolicRate" -> BasalMetabolicRateRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                basalMetabolicRate = Power.kilocaloriesPerDay(json.getDouble("kcalPerDay")),
                metadata = metadata,
            )
            "Hydration" -> HydrationRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                volume = Volume.liters(json.getDouble("volumeLiters")),
                metadata = metadata,
            )
            "Nutrition" -> buildNutrition(json, metadata)
            "MindfulnessSession" -> MindfulnessSessionRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                metadata = metadata,
                mindfulnessSessionType = json.intOrNull("mindfulnessSessionType")
                    ?: MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_UNKNOWN,
                title = json.stringOrNull("title"),
                notes = json.stringOrNull("notes"),
            )
            "MenstruationFlow" -> MenstruationFlowRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                flow = json.intOrNull("flow") ?: MenstruationFlowRecord.FLOW_UNKNOWN,
                metadata = metadata,
            )
            "MenstruationPeriod" -> MenstruationPeriodRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                metadata = metadata,
            )
            "OvulationTest" -> OvulationTestRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                result = json.intOrNull("result") ?: OvulationTestRecord.RESULT_INCONCLUSIVE,
                metadata = metadata,
            )
            "CervicalMucus" -> CervicalMucusRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                appearance = json.intOrNull("appearance") ?: CervicalMucusRecord.APPEARANCE_UNKNOWN,
                sensation = json.intOrNull("sensation") ?: CervicalMucusRecord.SENSATION_UNKNOWN,
                metadata = metadata,
            )
            "BasalBodyTemperature" -> BasalBodyTemperatureRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                temperature = Temperature.celsius(json.getDouble("temperatureCelsius")),
                measurementLocation = json.intOrNull("measurementLocation")
                    ?: BodyTemperatureMeasurementLocation.MEASUREMENT_LOCATION_UNKNOWN,
                metadata = metadata,
            )
            "IntermenstrualBleeding" -> IntermenstrualBleedingRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                metadata = metadata,
            )
            "SexualActivity" -> SexualActivityRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                protectionUsed = json.intOrNull("protectionUsed") ?: SexualActivityRecord.PROTECTION_USED_UNKNOWN,
                metadata = metadata,
            )
            "BloodPressure" -> BloodPressureRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                metadata = metadata,
                systolic = Pressure.millimetersOfMercury(json.getDouble("systolicMmHg")),
                diastolic = Pressure.millimetersOfMercury(json.getDouble("diastolicMmHg")),
                bodyPosition = json.intOrNull("bodyPosition") ?: BloodPressureRecord.BODY_POSITION_UNKNOWN,
                measurementLocation = json.intOrNull("measurementLocation")
                    ?: BloodPressureRecord.MEASUREMENT_LOCATION_UNKNOWN,
            )
            "OxygenSaturation" -> OxygenSaturationRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                percentage = Percentage(json.getDouble("percentage")),
                metadata = metadata,
            )
            "RespiratoryRate" -> RespiratoryRateRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                rate = json.getDouble("rate"),
                metadata = metadata,
            )
            "BodyTemperature" -> BodyTemperatureRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                temperature = Temperature.celsius(json.getDouble("temperatureCelsius")),
                measurementLocation = json.intOrNull("measurementLocation")
                    ?: BodyTemperatureMeasurementLocation.MEASUREMENT_LOCATION_UNKNOWN,
                metadata = metadata,
            )
            "SkinTemperature" -> SkinTemperatureRecord(
                startTime = json.instant("startEpochMs"),
                startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
                endTime = json.instant("endEpochMs"),
                endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
                metadata = metadata,
                deltas = json.samples("deltas") { s ->
                    SkinTemperatureRecord.Delta(
                        time = Instant.ofEpochMilli(s.getLong("timeEpochMs")),
                        delta = TemperatureDelta.celsius(s.getDouble("deltaCelsius")),
                    )
                },
                baseline = json.doubleOrNull("baselineCelsius")?.let { Temperature.celsius(it) },
                measurementLocation = json.intOrNull("measurementLocation")
                    ?: SkinTemperatureRecord.MEASUREMENT_LOCATION_UNKNOWN,
            )
            "BloodGlucose" -> BloodGlucoseRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                metadata = metadata,
                level = BloodGlucose.millimolesPerLiter(json.getDouble("levelMmolL")),
                specimenSource = json.intOrNull("specimenSource") ?: BloodGlucoseRecord.SPECIMEN_SOURCE_UNKNOWN,
                mealType = json.intOrNull("mealType") ?: MealTypeUnknown,
                relationToMeal = json.intOrNull("relationToMeal") ?: BloodGlucoseRecord.RELATION_TO_MEAL_UNKNOWN,
            )
            "Vo2Max" -> Vo2MaxRecord(
                time = json.instant("timeEpochMs"),
                zoneOffset = json.zoneOffsetOrNull("zoneOffsetSeconds"),
                vo2MillilitersPerMinuteKilogram = json.getDouble("vo2MillilitersPerMinuteKilogram"),
                measurementMethod = json.intOrNull("measurementMethod") ?: Vo2MaxRecord.MEASUREMENT_METHOD_OTHER,
                metadata = metadata,
            )
            else -> throw IllegalArgumentException("Unknown record type: $recordType")
        }
    }

    private fun buildExerciseSession(json: JSONObject, metadata: Metadata): ExerciseSessionRecord {
        val segments = json.samples("segments") { s ->
            ExerciseSegment(
                startTime = Instant.ofEpochMilli(s.getLong("startEpochMs")),
                endTime = Instant.ofEpochMilli(s.getLong("endEpochMs")),
                segmentType = s.getInt("segmentType"),
                repetitions = s.intOrNull("repetitions") ?: 0,
            )
        }
        val laps = json.samples("laps") { s ->
            ExerciseLap(
                startTime = Instant.ofEpochMilli(s.getLong("startEpochMs")),
                endTime = Instant.ofEpochMilli(s.getLong("endEpochMs")),
                length = s.doubleOrNull("lengthMeters")?.let { Length.meters(it) },
            )
        }
        val route = json.optJSONObject("route")?.optJSONArray("points")?.let { points ->
            val locations = ArrayList<ExerciseRoute.Location>(points.length())
            for (i in 0 until points.length()) {
                val p = points.getJSONObject(i)
                locations.add(
                    ExerciseRoute.Location(
                        time = Instant.ofEpochMilli(p.getLong("timeEpochMs")),
                        latitude = p.getDouble("latitude"),
                        longitude = p.getDouble("longitude"),
                        horizontalAccuracy = p.doubleOrNull("horizontalAccuracyMeters")?.let { Length.meters(it) },
                        verticalAccuracy = p.doubleOrNull("verticalAccuracyMeters")?.let { Length.meters(it) },
                        altitude = p.doubleOrNull("altitudeMeters")?.let { Length.meters(it) },
                    ),
                )
            }
            if (locations.isEmpty()) null else ExerciseRoute(locations)
        }
        // `route` is statically typed `ExerciseRoute?`, which resolves the
        // ExerciseRoute constructor overload unambiguously (even when null).
        return ExerciseSessionRecord(
            startTime = json.instant("startEpochMs"),
            startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
            endTime = json.instant("endEpochMs"),
            endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
            metadata = metadata,
            exerciseType = json.getInt("exerciseType"),
            title = json.stringOrNull("title"),
            notes = json.stringOrNull("notes"),
            segments = segments,
            laps = laps,
            exerciseRoute = route,
            plannedExerciseSessionId = json.stringOrNull("plannedExerciseSessionId"),
        )
    }

    private fun buildNutrition(json: JSONObject, metadata: Metadata): NutritionRecord {
        fun grams(vararg keys: String): Mass? {
            for (key in keys) {
                json.doubleOrNull(key)?.let { return Mass.grams(it) }
            }
            return null
        }
        return NutritionRecord(
            startTime = json.instant("startEpochMs"),
            startZoneOffset = json.zoneOffsetOrNull("startZoneOffsetSeconds"),
            endTime = json.instant("endEpochMs"),
            endZoneOffset = json.zoneOffsetOrNull("endZoneOffsetSeconds"),
            metadata = metadata,
            name = json.stringOrNull("name"),
            mealType = json.intOrNull("mealType") ?: MealTypeUnknown,
            energy = json.doubleOrNull("energyKcal")?.let { Energy.kilocalories(it) },
            energyFromFat = json.doubleOrNull("energyFromFatKcal")?.let { Energy.kilocalories(it) },
            biotin = grams("biotin"),
            caffeine = grams("caffeine"),
            calcium = grams("calcium"),
            chloride = grams("chloride"),
            cholesterol = grams("cholesterol"),
            chromium = grams("chromium"),
            copper = grams("copper"),
            dietaryFiber = grams("fiber", "dietaryFiber"),
            folate = grams("folate"),
            folicAcid = grams("folicAcid"),
            iodine = grams("iodine"),
            iron = grams("iron"),
            magnesium = grams("magnesium"),
            manganese = grams("manganese"),
            molybdenum = grams("molybdenum"),
            monounsaturatedFat = grams("monounsaturatedFat"),
            niacin = grams("niacin"),
            pantothenicAcid = grams("pantothenicAcid"),
            phosphorus = grams("phosphorus"),
            polyunsaturatedFat = grams("polyunsaturatedFat"),
            potassium = grams("potassium"),
            protein = grams("protein"),
            riboflavin = grams("riboflavin"),
            saturatedFat = grams("saturatedFat"),
            selenium = grams("selenium"),
            sodium = grams("sodium"),
            sugar = grams("sugar"),
            thiamin = grams("thiamin"),
            totalCarbohydrate = grams("totalCarbohydrate"),
            totalFat = grams("totalFat"),
            transFat = grams("transFat"),
            unsaturatedFat = grams("unsaturatedFat"),
            vitaminA = grams("vitaminA"),
            vitaminB12 = grams("vitaminB12"),
            vitaminB6 = grams("vitaminB6"),
            vitaminC = grams("vitaminC"),
            vitaminD = grams("vitaminD"),
            vitaminE = grams("vitaminE"),
            vitaminK = grams("vitaminK"),
            zinc = grams("zinc"),
        )
    }

    private fun buildMetadata(json: JSONObject): Metadata {
        val clientRecordId = json.stringOrNull("clientRecordId")
        val clientRecordVersion = json.longOrNull("clientRecordVersion") ?: 0L
        val device = json.optJSONObject("device")?.let { d ->
            Device(
                type = d.intOrNull("type") ?: Device.TYPE_UNKNOWN,
                manufacturer = d.stringOrNull("manufacturer"),
                model = d.stringOrNull("model"),
            )
        }
        return when (json.intOrNull("recordingMethod")) {
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED -> {
                val dev = device ?: Device(type = Device.TYPE_UNKNOWN)
                if (clientRecordId != null) {
                    Metadata.autoRecorded(
                        device = dev,
                        clientRecordId = clientRecordId,
                        clientRecordVersion = clientRecordVersion,
                    )
                } else {
                    Metadata.autoRecorded(device = dev)
                }
            }
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED -> {
                val dev = device ?: Device(type = Device.TYPE_UNKNOWN)
                if (clientRecordId != null) {
                    Metadata.activelyRecorded(
                        device = dev,
                        clientRecordId = clientRecordId,
                        clientRecordVersion = clientRecordVersion,
                    )
                } else {
                    Metadata.activelyRecorded(device = dev)
                }
            }
            else -> {
                when {
                    clientRecordId != null && device != null -> Metadata.manualEntry(
                        clientRecordId = clientRecordId,
                        clientRecordVersion = clientRecordVersion,
                        device = device,
                    )
                    clientRecordId != null -> Metadata.manualEntry(
                        clientRecordId = clientRecordId,
                        clientRecordVersion = clientRecordVersion,
                    )
                    device != null -> Metadata.manualEntry(device = device)
                    else -> Metadata.manualEntry()
                }
            }
        }
    }

    /**
     * Nutrient mass fields for read serialization, keyed by JSON key (camelCase
     * per the schema; `dietaryFiber` is exposed as `fiber`).
     */
    private val NUTRITION_MASS_FIELDS: List<Pair<String, (NutritionRecord) -> Mass?>> = listOf(
        "biotin" to { it.biotin },
        "caffeine" to { it.caffeine },
        "calcium" to { it.calcium },
        "chloride" to { it.chloride },
        "cholesterol" to { it.cholesterol },
        "chromium" to { it.chromium },
        "copper" to { it.copper },
        "fiber" to { it.dietaryFiber },
        "folate" to { it.folate },
        "folicAcid" to { it.folicAcid },
        "iodine" to { it.iodine },
        "iron" to { it.iron },
        "magnesium" to { it.magnesium },
        "manganese" to { it.manganese },
        "molybdenum" to { it.molybdenum },
        "monounsaturatedFat" to { it.monounsaturatedFat },
        "niacin" to { it.niacin },
        "pantothenicAcid" to { it.pantothenicAcid },
        "phosphorus" to { it.phosphorus },
        "polyunsaturatedFat" to { it.polyunsaturatedFat },
        "potassium" to { it.potassium },
        "protein" to { it.protein },
        "riboflavin" to { it.riboflavin },
        "saturatedFat" to { it.saturatedFat },
        "selenium" to { it.selenium },
        "sodium" to { it.sodium },
        "sugar" to { it.sugar },
        "thiamin" to { it.thiamin },
        "totalCarbohydrate" to { it.totalCarbohydrate },
        "totalFat" to { it.totalFat },
        "transFat" to { it.transFat },
        "unsaturatedFat" to { it.unsaturatedFat },
        "vitaminA" to { it.vitaminA },
        "vitaminB12" to { it.vitaminB12 },
        "vitaminB6" to { it.vitaminB6 },
        "vitaminC" to { it.vitaminC },
        "vitaminD" to { it.vitaminD },
        "vitaminE" to { it.vitaminE },
        "vitaminK" to { it.vitaminK },
        "zinc" to { it.zinc },
    )

    /**
     * `MealType.MEAL_TYPE_UNKNOWN` is `0`; referenced by literal to avoid an
     * import that some connect-client versions place differently.
     */
    private const val MealTypeUnknown = 0
}

// -----------------------------------------------------------------------------
// JSON helper extensions (null-safe accessors)
// -----------------------------------------------------------------------------

private fun JSONObject.instant(key: String): Instant = Instant.ofEpochMilli(getLong(key))

private fun JSONObject.zoneOffsetOrNull(key: String): ZoneOffset? =
    if (has(key) && !isNull(key)) ZoneOffset.ofTotalSeconds(getInt(key)) else null

private fun JSONObject.doubleOrNull(key: String): Double? =
    if (has(key) && !isNull(key)) getDouble(key) else null

private fun JSONObject.longOrNull(key: String): Long? =
    if (has(key) && !isNull(key)) getLong(key) else null

private fun JSONObject.intOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) getInt(key) else null

private fun JSONObject.stringOrNull(key: String): String? =
    if (has(key) && !isNull(key)) getString(key) else null

private inline fun <T> JSONObject.samples(key: String, factory: (JSONObject) -> T): List<T> {
    val array = optJSONArray(key) ?: return emptyList()
    val out = ArrayList<T>(array.length())
    for (i in 0 until array.length()) {
        out.add(factory(array.getJSONObject(i)))
    }
    return out
}

/**
 * Body/basal temperature `MEASUREMENT_LOCATION_UNKNOWN` is `0` across the
 * connect-client versions in use.
 */
private object BodyTemperatureMeasurementLocation {
    const val MEASUREMENT_LOCATION_UNKNOWN = 0
}
