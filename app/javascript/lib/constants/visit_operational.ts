export const VISIT_ACCESS_POINTS = ['main_entrance', 'side_entrance', 'garage'] as const
export const VISIT_ACCESS_TYPES = ['pedestrian', 'vehicle', 'delivery', 'other'] as const
export const VISIT_INCIDENT_TYPES = ['none', 'noise', 'damage', 'security', 'other'] as const

export type VisitAccessPoint = (typeof VISIT_ACCESS_POINTS)[number]
export type VisitAccessType = (typeof VISIT_ACCESS_TYPES)[number]
export type VisitIncidentType = (typeof VISIT_INCIDENT_TYPES)[number]

export const VISIT_NOTES_MAX_LENGTH = 200
