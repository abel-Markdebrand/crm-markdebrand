import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal();

  static const String _model = 'project.project';

  /// Get the list of projects for the current user
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      final uid = OdooService.instance.uid;
      if (uid == null) throw Exception("User not logged in");

      final domain = [
        ['active', '=', true],
        ['user_id', '=', uid],
      ];

      dynamic response;
      try {
        response = await OdooService.instance.callKw(
          model: _model,
          method: 'search_read',
          args: [domain],
          kwargs: {
            'fields': [
              'id',
              'name',
              'user_id',
              'partner_id',
              'task_count',
              'label_tasks',
              'color',
              'privacy_visibility',
              'description',
              'tag_ids',
              'date_start',
              'date',
            ],
            'order': 'name asc',
          },
        );
      } catch (e) {
        debugPrint("Primary project fetch failed: $e");
      }

      if (response == null || (response is List && response.isEmpty)) {
        try {
          // Fallback 1: Try common fields
          response = await OdooService.instance.callKw(
            model: _model,
            method: 'search_read',
            args: [[]],
            kwargs: {
              'fields': ['id', 'name', 'task_count', 'partner_id', 'user_id'],
              'limit': 100,
              'order': 'name asc',
            },
          );
        } catch (e) {
          debugPrint("First project fallback failed: $e");
        }

        if (response == null || (response is List && response.isEmpty)) {
          // Fallback 2: Absolute minimal fields
          response = await OdooService.instance.callKw(
            model: _model,
            method: 'search_read',
            args: [[]],
            kwargs: {
              'fields': ['id', 'name'],
              'limit': 100,
            },
          );
        }
      }

      if (response != null && response is List) {
        final List<Map<String, dynamic>> projects =
            List<Map<String, dynamic>>.from(response);

        // Fetch tag names if tag_ids exist
        final Set<int> allTagIds = {};
        for (var project in projects) {
          if (project['tag_ids'] is List) {
            for (var tid in project['tag_ids']) {
              if (tid is int) allTagIds.add(tid);
            }
          }
        }

        if (allTagIds.isNotEmpty) {
          try {
            final tagsResponse = await OdooService.instance.callKw(
              model: 'project.tags',
              method: 'search_read',
              args: [
                [
                  ['id', 'in', allTagIds.toList()],
                ],
              ],
              kwargs: {
                'fields': ['id', 'name'],
              },
            );
            if (tagsResponse is List) {
              final Map<int, String> tagNames = {};
              for (var t in tagsResponse) {
                if (t is Map && t['id'] is int && t['name'] is String) {
                  tagNames[t['id']] = t['name'];
                }
              }
              for (var project in projects) {
                if (project['tag_ids'] is List) {
                  project['tag_ids'] = (project['tag_ids'] as List).map((tid) {
                    if (tid is int && tagNames.containsKey(tid)) {
                      return [tid, tagNames[tid]];
                    }
                    return tid; // Fallback to raw ID or existing list format
                  }).toList();
                }
              }
            }
          } catch (e) {
            debugPrint("Failed to fetch project tags: $e");
          }
        }

        return projects;
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching projects: $e");
      return [];
    }
  }

  /// Create a new project
  Future<int?> createProject(Map<String, dynamic> data) async {
    // Attempt 1: Full data
    try {
      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'create',
        args: [data],
      );
      if (response is int) return response;
    } catch (e) {
      debugPrint("Error creating project (Attempt 1): $e");
    }

    // Attempt 2: Remove description (sometimes HTML formatting or long text causes issues)
    try {
      final Map<String, dynamic> noDescData = Map.from(data);
      noDescData.remove('description');
      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'create',
        args: [noDescData],
      );
      if (response is int) return response;
    } catch (e) {
      debugPrint("Error creating project (Attempt 2 - no desc): $e");
    }

    // Attempt 3: Minimal data (just name)
    try {
      final Map<String, dynamic> minimalData = {'name': data['name']};
      final response = await OdooService.instance.callKw(
        model: _model,
        method: 'create',
        args: [minimalData],
      );
      if (response is int) return response;
    } catch (e) {
      debugPrint("Error creating project (Attempt 3 - minimal): $e");
    }

    return null;
  }

  /// Update an existing project
  Future<bool> updateProject(int projectId, Map<String, dynamic> data) async {
    try {
      await OdooService.instance.callKw(
        model: _model,
        method: 'write',
        args: [
          [projectId],
          data,
        ],
      );
      return true;
    } catch (e) {
      debugPrint("Error updating project: $e");
      return false;
    }
  }

  /// Search for partners (Clients)
  Future<List<Map<String, dynamic>>> searchPartners(String query) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'res.partner',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['name', 'ilike', query],
          ],
          'fields': ['id', 'name'],
          'limit': 20,
        },
      );
      if (response is List) return List<Map<String, dynamic>>.from(response);
      return [];
    } catch (e) {
      debugPrint("Error searching partners: $e");
      return [];
    }
  }

  /// Search for users (Managers)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'res.users',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['name', 'ilike', query],
          ],
          'fields': ['id', 'name'],
          'limit': 20,
        },
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  /// Search for Tags
  Future<List<Map<String, dynamic>>> searchTags(String query) async {
    try {
      final response = await OdooService.instance.callKw(
        model: 'project.tags',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': [
            ['name', 'ilike', query],
          ],
          'fields': ['id', 'name'],
          'limit': 20,
        },
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error searching tags: $e");
      return [];
    }
  }

  /// Search for Milestones
  Future<List<Map<String, dynamic>>> searchMilestones(
    String query,
    int? projectId,
  ) async {
    try {
      List<dynamic> domain = [
        ['name', 'ilike', query],
      ];
      if (projectId != null) {
        domain.add(['project_id', '=', projectId]);
      }
      final response = await OdooService.instance.callKw(
        model: 'project.milestone',
        method: 'search_read',
        args: [],
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name'],
          'limit': 20,
        },
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error searching milestones: $e");
      return [];
    }
  }

  /// Helper to get multiple records directly by their IDs
  Future<List<Map<String, dynamic>>> getRecordsByIds(
    String model,
    List<dynamic> ids,
  ) async {
    if (ids.isEmpty) return [];
    try {
      final response = await OdooService.instance.callKw(
        model: model,
        method: 'search_read',
        args: [
          [
            ['id', 'in', ids],
          ],
        ],
        kwargs: {
          'fields': ['id', 'name'],
        },
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching records by IDs for $model: $e");
      return [];
    }
  }

  // --- CACHE DE CAMPOS EN MEMORIA ---
  // Key: modelName, Value: Lista de nombres de campos que existen en el servidor
  final Map<String, List<String>> _modelFieldsCache = {};

  /// Obtiene de forma segura y cacheada los campos disponibles para un modelo
  Future<List<String>> _getAvailableFields(
    String model,
    List<String> requestedFields,
  ) async {
    if (!_modelFieldsCache.containsKey(model)) {
      try {
        debugPrint(
          "🔍 [ProjectService] Consultando fields_get para el modelo: $model",
        );
        final response = await OdooService.instance.callKw(
          model: model,
          method: 'fields_get',
          args: [],
          kwargs: {
            'attributes': ['string', 'type'],
          },
        );

        if (response is Map) {
          _modelFieldsCache[model] = response.keys
              .map((k) => k.toString())
              .toList();
          debugPrint(
            "✅ [ProjectService] Cache cargado con ${_modelFieldsCache[model]!.length} campos para $model",
          );
        } else {
          _modelFieldsCache[model] = [];
        }
      } catch (e) {
        debugPrint(
          "⚠️ [ProjectService] Error al obtener fields_get de $model: $e",
        );
        // En caso de fallo, intentamos continuar asumiendo que algunos campos core existen
        // para no bloquear completamente la UI.
        return requestedFields;
      }
    }

    final available = _modelFieldsCache[model] ?? [];
    if (available.isEmpty) return requestedFields; // Fallback fail-safe

    return requestedFields.where((field) => available.contains(field)).toList();
  }

  /// Get tasks for a specific project
  Future<List<Map<String, dynamic>>> getTasks(int projectId) async {
    final String model = 'project.task';
    final baseDomain = [
      ['project_id', '=', projectId],
      ['active', '=', true],
    ];

    // Lista IDEAL de campos que nos gustaría traer (abarca Odoo 14 a 18)
    final idealFields = [
      'id',
      'name',
      'user_id', // Odoo 14, 15, 16
      'user_ids', // Odoo >= 16/17 (Múltiples asignados)
      'partner_id', // En caso de que se asigne al cliente en Odoo web
      'manager_id', // A veces se usa en proyectos
      'stage_id',
      'tag_ids',
      'milestone_id',
      'description',
      'priority',
      'date_deadline',
      'kanban_state',
      'planned_hours', // Odoo <= 16
      'allocated_hours', // Odoo >= 17
      'effective_hours',
    ];

    try {
      // 1. Filtrar dinámicamente campos inexistentes
      final validFields = await _getAvailableFields(model, idealFields);
      debugPrint(
        "✅ [ProjectService] Campos filtrados listos: ${validFields.join(', ')}",
      );

      // 2. Ejecutar búsqueda
      dynamic response = await OdooService.instance.callKw(
        model: model,
        method: 'search_read',
        args: [baseDomain],
        kwargs: {
          'fields': validFields,
          // Ordenamos primero por etapa, prioridad (descendente) y ID (descendente)
          'order': 'stage_id asc, priority desc, id desc',
          'limit': 150, // Previene carga infinita en proyectos gigantes
        },
      );

      if (response != null && response is List) {
        // 3. Normalización y Safe Parsing
        final List<Map<String, dynamic>> tasks = response.map((e) {
          if (e is! Map) return <String, dynamic>{};

          // Clonamos de forma segura garantizando Map<String, dynamic>
          final Map<String, dynamic> safeMap = e.map(
            (key, value) => MapEntry(key.toString(), value),
          );

          // Normalización de Many2One / Many2Many -> Asignado
          if (safeMap['user_ids'] is List &&
              (safeMap['user_ids'] as List).isNotEmpty) {
            // Odoo 17+ (Puede venir con varios asignados)
            if (!safeMap.containsKey('user_id') ||
                safeMap['user_id'] == false) {
              // Dejamos que la UI actual decida, pero proveemos ambos campos.
              // La UI ya hace: task['user_id'] is List ? task['user_id'][1] : ...
            }
          }

          // Normalización de Prioridad (Asegurar Int para evitar fallos de parseo en UI)
          if (safeMap['priority'] != null) {
            safeMap['priority'] =
                int.tryParse(safeMap['priority'].toString()) ?? 0;
          }

          return safeMap;
        }).toList();

        // 3.5. Batch Fetch Assignees Names
        final Set<int> allUserIds = {};
        for (var task in tasks) {
          if (task['user_ids'] is List) {
            for (var uid in (task['user_ids'] as List)) {
              if (uid is int) allUserIds.add(uid);
            }
          }
          if (task['user_id'] is List && (task['user_id'] as List).isNotEmpty) {
            if (task['user_id'][0] is int) {
              allUserIds.add(task['user_id'][0] as int);
            }
          } else if (task['user_id'] is int) {
            allUserIds.add(task['user_id'] as int);
          }
        }

        final Map<int, String> userNames = {};
        if (allUserIds.isNotEmpty) {
          try {
            // Buscamos primero en el modelo de usuarios 'res.users' para coincidencia de IDs
            final usersResponse = await OdooService.instance.callKw(
              model: 'res.users',
              method: 'search_read',
              args: [
                [
                  ['id', 'in', allUserIds.toList()],
                  '|',
                  ['active', '=', true],
                  ['active', '=', false],
                ],
              ],
              kwargs: {
                'fields': ['id', 'partner_id', 'name'],
              },
            );
            if (usersResponse is List) {
              for (var u in usersResponse) {
                if (u is Map && u['id'] is int && u['name'] is String) {
                  userNames[u['id'] as int] = u['name'] as String;
                }
              }
            }
          } catch (e) {
            debugPrint(
              "⏳ [ProjectService] Failed to batch fetch user names from res.users: $e",
            );
          }

          // Try fetching from res.partner if not found in res.users
          if (userNames.length < allUserIds.length) {
            try {
              final missingIds = allUserIds
                  .where((id) => !userNames.containsKey(id))
                  .toList();
              final partnersResponse = await OdooService.instance.callKw(
                model: 'res.partner',
                method: 'search_read',
                args: [
                  [
                    ['id', 'in', missingIds],
                    '|',
                    ['active', '=', true],
                    ['active', '=', false],
                  ],
                ],
                kwargs: {
                  'fields': ['id', 'name'],
                },
              );
              if (partnersResponse is List) {
                for (var p in partnersResponse) {
                  if (p is Map && p['id'] is int && p['name'] is String) {
                    userNames[p['id'] as int] = p['name'] as String;
                  }
                }
              }
            } catch (e) {
              debugPrint(
                "⏳ [ProjectService] Failed fallback to res.partner: $e",
              );
            }
          }
        }

        // Inject assignee_names
        for (var task in tasks) {
          List<String> names = [];
          if (task['user_ids'] is List) {
            for (var uid in (task['user_ids'] as List)) {
              if (uid is int) {
                if (userNames.containsKey(uid)) {
                  names.add(userNames[uid]!);
                } else {
                  names.add(
                    "Asignado $uid",
                  ); // Fallback if name not found in batch fetch
                }
              }
            }
          }

          if (names.isEmpty &&
              task['user_id'] is List &&
              (task['user_id'] as List).length >= 2) {
            names.add(task['user_id'][1].toString());
          } else if (names.isEmpty && task['user_id'] is int) {
            if (userNames.containsKey(task['user_id'])) {
              names.add(userNames[task['user_id']]!);
            } else {
              // Try asking for partner_id name instead!
              if (task['partner_id'] is List &&
                  (task['partner_id'] as List).length >= 2) {
                names.add(task['partner_id'][1].toString());
              } else {
                names.add("Asignado ${task['user_id']}"); // Fallback
              }
            }
          }

          // Fallback 2: partner_id (Cliente)
          if (names.isEmpty &&
              task['partner_id'] is List &&
              (task['partner_id'] as List).length >= 2) {
            names.add("${task['partner_id'][1]} (Cliente)");
          }

          // Fallback 3: manager_id
          if (names.isEmpty &&
              task['manager_id'] is List &&
              (task['manager_id'] as List).length >= 2) {
            names.add("${task['manager_id'][1]} (Manager)");
          }

          // Fallback final: Debugging string para ver qué llegó realmente
          if (names.isEmpty) {
            String debugData = "Vacío ";
            if (task.containsKey('user_ids')) {
              debugData += "[u_ids: ${task['user_ids']}] ";
            }
            if (task.containsKey('user_id')) {
              debugData += "[u_id: ${task['user_id']}] ";
            }
            if (task.containsKey('partner_id')) {
              debugData += "[p_id: ${task['partner_id']}] ";
            }
            names.add(debugData);
          }

          task['assignee_names'] = names;
        }

        // 4. Verificación de Tareas Ocultas (solo si active=false)
        if (tasks.isEmpty) {
          try {
            final hiddenCheck = await OdooService.instance.callKw(
              model: model,
              method: 'search_count',
              args: [
                [
                  ['project_id', '=', projectId],
                  ['active', '=', false],
                ],
              ],
            );
            if (hiddenCheck is int && hiddenCheck > 0) {
              return [
                {
                  'id': -2,
                  'name': 'TAREAS OCULTAS POR FILTRO (ACTIVE=FALSE)',
                  'priority': 0, // int format
                  'description':
                      'Hay $hiddenCheck tareas archivadas o terminadas que no se muestran aquí porque active=false.',
                },
              ];
            }
          } catch (_) {
            /* Ignorar error de chequeo secundario */
          }
        }

        return tasks;
      }
      return [];
    } catch (e, stacktrace) {
      debugPrint(
        "❌ [ProjectService] Error fetchTasks (Avanzado): $e\n$stacktrace",
      );

      // 5. Retry Strategy (Modo Rescate Fallback Absoluto)
      try {
        debugPrint("🔄 [ProjectService] Intentando modo rescate...");
        dynamic rescueResponse = await OdooService.instance.callKw(
          model: model,
          method: 'search_read',
          args: [
            [
              ['project_id', '=', projectId],
            ],
          ], // sin active=true ni order que puedan fallar
          kwargs: {
            'fields': ['id', 'name'],
            'limit': 50,
          },
        );
        if (rescueResponse is List) {
          final List<Map<String, dynamic>> rescueTasks = rescueResponse
              .map(
                (e) => e is Map
                    ? e.map((k, v) => MapEntry(k.toString(), v))
                    : <String, dynamic>{},
              )
              .toList();
          rescueTasks.insert(0, {
            'id': -1,
            'name': 'Modo Rescate Activo',
            'description':
                'Hubo un error cargando datos completos, se muestran solo IDs y nombres.',
            'priority': 0,
          });
          return rescueTasks;
        }
      } catch (retryError) {
        debugPrint("❌ [ProjectService] Modo rescate falló: $retryError");
      }

      return [
        {
          'id': -999,
          'name': 'CRASH EN BÚSQUEDA DE TAREAS',
          'description': "$e\n$stacktrace",
          'priority': 0, // int fallback
        },
      ];
    }
  }

  /// Get project stages (types) for a project or globally
  Future<List<Map<String, dynamic>>> getProjectStages(int projectId) async {
    try {
      // In Odoo, stages are often project-specific or linked via project_ids
      final response = await OdooService.instance.callKw(
        model: 'project.task.type',
        method: 'search_read',
        args: [
          [
            '|',
            ['project_ids', '=', false],
            [
              'project_ids',
              'in',
              [projectId],
            ],
          ],
        ],
        kwargs: {
          'fields': ['id', 'name', 'sequence'],
          'order': 'sequence asc',
        },
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching stages for project $projectId: $e");
      return [];
    }
  }

  /// Create a new task
  Future<int?> createTask(Map<String, dynamic> data) async {
    // Attempt 1: Full data as provided
    final dynamic result = await _performTaskAction('create', [data]);
    if (result is int) return result;

    // Attempt 2: Swap planned_hours <-> allocated_hours
    final Map<String, dynamic> swappedData = Map.from(data);
    if (swappedData.containsKey('planned_hours')) {
      swappedData['allocated_hours'] = swappedData.remove('planned_hours');
    } else if (swappedData.containsKey('allocated_hours')) {
      swappedData['planned_hours'] = swappedData.remove('allocated_hours');
    }
    final dynamic result2 = await _performTaskAction('create', [swappedData]);
    if (result2 is int) return result2;

    // Attempt 3: Remove hours entirely but keep everything else (assignments, dates, description, tags)
    final Map<String, dynamic> noHoursData = Map.from(data);
    noHoursData.remove('planned_hours');
    noHoursData.remove('allocated_hours');
    final dynamic result3 = await _performTaskAction('create', [noHoursData]);
    if (result3 is int) return result3;

    // Attempt 4: Remove priority and dates (sometimes causes issues if types mismatch)
    final Map<String, dynamic> simplerData = Map.from(noHoursData);
    simplerData.remove('priority');
    simplerData.remove('date_deadline');
    final dynamic result4 = await _performTaskAction('create', [simplerData]);
    if (result4 is int) return result4;

    // Attempt 5: Absolute minimal (just name, project, and stage)
    final Map<String, dynamic> absoluteMinimal = {
      'name': data['name'],
      'project_id': data['project_id'],
    };
    if (data.containsKey('stage_id')) {
      absoluteMinimal['stage_id'] = data['stage_id'];
    }

    return await _performTaskAction('create', [absoluteMinimal]) as int?;
  }

  /// Update an existing task
  Future<bool> updateTask(int taskId, Map<String, dynamic> data) async {
    // Try to update with provided data
    final dynamic result = await _performTaskAction('write', [
      [taskId],
      data,
    ]);
    if (result == true) return true;

    // Fallback: Swapped hours
    final Map<String, dynamic> swappedData = Map.from(data);
    if (swappedData.containsKey('planned_hours')) {
      swappedData['allocated_hours'] = swappedData.remove('planned_hours');
    }
    final dynamic result2 = await _performTaskAction('write', [
      [taskId],
      swappedData,
    ]);
    if (result2 == true) return true;

    return false;
  }

  /// Helper to perform task actions with assignment handling
  Future<dynamic> _performTaskAction(String method, List<dynamic> args) async {
    final List<dynamic> localArgs = List.from(args);
    final Map<String, dynamic> originalData = localArgs.last is Map
        ? Map<String, dynamic>.from(localArgs.last)
        : {};

    final Map<String, dynamic> data = Map.from(originalData);

    // Handle Priority
    if (data.containsKey('priority') && data['priority'] != null) {
      data['priority'] = data['priority'].toString();
    }

    // Handle Stage
    if (data.containsKey('stage_id') && data['stage_id'] == null) {
      data.remove('stage_id');
    }

    // We prepare a modern payload (Odoo 17/18) and a legacy payload (Odoo 16-)
    if (data.containsKey('user_id') &&
        data['user_id'] != null &&
        data['user_id'] != false) {
      final userId = data['user_id'];
      data['user_ids'] = [
        [
          6,
          0,
          [userId],
        ],
      ];
    }

    // PRIMARY ATTEMPT (Odoo 17/18 style - prefer user_ids, drop user_id)
    try {
      final Map<String, dynamic> modernData = Map.from(data);
      if (modernData.containsKey('user_ids')) {
        modernData.remove(
          'user_id',
        ); // Odoo 17 usually fails if inherited user_id is sent
      }
      return await OdooService.instance.callKw(
        model: 'project.task',
        method: method,
        args: method == 'create' ? [modernData] : [localArgs.first, modernData],
      );
    } catch (e1) {
      debugPrint("Odoo Task Action ($method) modern attempt failed: $e1");

      // FALLBACK ATTEMPT (Odoo 16- style - prefer user_id, drop user_ids)
      try {
        final Map<String, dynamic> legacyData = Map.from(originalData);
        if (legacyData.containsKey('priority') &&
            legacyData['priority'] != null) {
          legacyData['priority'] = legacyData['priority'].toString();
        }
        return await OdooService.instance.callKw(
          model: 'project.task',
          method: method,
          args: method == 'create'
              ? [legacyData]
              : [localArgs.first, legacyData],
        );
      } catch (e2) {
        debugPrint("Odoo Task Action ($method) legacy attempt failed: $e2");
        return null; // Both failed
      }
    }
  }

  /// DEBUG: Get fields of a model to check available names
  Future<void> debugModelFields(String model) async {
    try {
      final response = await OdooService.instance.callKw(
        model: model,
        method: 'fields_get',
        args: [],
        kwargs: {
          'attributes': ['string', 'type', 'required', 'readonly'],
        },
      );
      debugPrint("Fields for $model: $response");
    } catch (e) {
      debugPrint("Error debugging fields for $model: $e");
    }
  }

  /// DEBUG: Trace project fetching issues
  Future<void> traceProjectIssues() async {
    try {
      final uid = OdooService.instance.uid;
      debugPrint("Tracing Projects for UID: $uid");
      final allProjects = await OdooService.instance.callKw(
        model: _model,
        method: 'search_read',
        args: [[]],
        kwargs: {
          'fields': ['id', 'name', 'active', 'user_id'],
          'limit': 10,
        },
      );
      debugPrint("Sample Projects (All): $allProjects");
    } catch (e) {
      debugPrint("Trace failed: $e");
    }
  }

  /// Create a timesheet entry
  Future<int?> createTimesheetLine({
    required int projectId,
    required int taskId,
    required double hours,
    required String description,
    DateTime? date,
  }) async {
    try {
      final uid = OdooService.instance.uid;
      final data = {
        'project_id': projectId,
        'task_id': taskId,
        'unit_amount': hours,
        'name': description,
        'date': DateFormat('yyyy-MM-dd').format(date ?? DateTime.now()),
        'user_id': uid,
      };

      final response = await OdooService.instance.callKw(
        model: 'account.analytic.line',
        method: 'create',
        args: [data],
      );
      if (response is int) return response;
      return null;
    } catch (e) {
      debugPrint("Error creating timesheet line: $e");
      return null;
    }
  }
}
