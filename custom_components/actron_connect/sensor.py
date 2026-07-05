"""Support for Actron AC sensors."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import UnitOfTemperature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .const import ATTR_INSIDE_TEMPERATURE, ATTR_ZONE_INSIDE_TEMPERATURE
from .coordinator import ActronConfigEntry, ActronCoordinator
from .entity import ActronEntity
from .pyactron.appliance import Appliance

@dataclass(frozen=True, kw_only=True)
class ActronSensorEntityDescription(SensorEntityDescription):
    """Describes Actron sensor entity."""
    value_func: Callable[[Appliance], float | None]

async def async_setup_entry(
    _hass: HomeAssistant,
    entry: ActronConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Set up Actron climate based on config_entry."""
    coordinator = entry.runtime_data

    main_temperature_sensor_description = ActronSensorEntityDescription(
        key=ATTR_INSIDE_TEMPERATURE,
        translation_key="inside_temperature",
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        value_func=lambda device: device.current_temperature,
    )

    zone_temperature_sensor_description = ActronSensorEntityDescription(
        key=ATTR_ZONE_INSIDE_TEMPERATURE,
        translation_key="zone_inside_temperature",
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        value_func=lambda device, zone_id: device.individual_zone_temperatures[zone_id],
    )
    sensors: list[SensorEntity] = []

    # Add inside temperature sensor
    sensors.append(ActronSensor(coordinator, main_temperature_sensor_description))

    # Add zone temperature sensors
    if zone_names := coordinator.device.zone_names:
        sensors.extend(
            ActronIndividualZoneTemperatureSensor(coordinator, zone_temperature_sensor_description, zone_id, zone_name)
            for zone_id, zone_name in enumerate[str](zone_names)
        )

    async_add_entities(sensors)

class ActronIndividualZoneTemperatureSensor(ActronEntity, SensorEntity):
    """Representation of a individual zone temperature sensor."""

    entity_description: ActronSensorEntityDescription

    def __init__(self, coordinator: ActronCoordinator, description: ActronSensorEntityDescription, zone_id: int, zone_name: str) -> None:
        """Initialize the sensor."""
        super().__init__(coordinator)
        self._zone_id = zone_id
        self.entity_description = description
        self._zone_name = f"Zone Temperature - {zone_name}"
        self._attr_unique_id = f"{self.device.mac}-zone-{zone_id}"

    @property
    def name(self) -> str:
        """Return the name of the sensor."""
        return self._zone_name

    @property
    def native_value(self) -> float | None:
        """Return the state of the sensor."""
        return self.entity_description.value_func(self.device, self._zone_id)

class ActronSensor(ActronEntity, SensorEntity):
    """Representation of a Sensor."""

    entity_description: ActronSensorEntityDescription

    def __init__(
        self, coordinator: ActronCoordinator, description: ActronSensorEntityDescription
    ) -> None:
        """Initialize the sensor."""
        super().__init__(coordinator)
        self.entity_description = description
        self._attr_unique_id = f"{self.device.device_id}-{description.key}"

    @property
    def native_value(self) -> float | None:
        """Return the state of the sensor."""
        return self.entity_description.value_func(self.device)
