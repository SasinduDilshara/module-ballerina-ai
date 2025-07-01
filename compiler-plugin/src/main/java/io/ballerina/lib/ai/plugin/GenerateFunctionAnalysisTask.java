/*
 * Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.ai.plugin;

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.syntax.tree.MethodCallExpressionNode;
import io.ballerina.compiler.syntax.tree.ModulePartNode;
import io.ballerina.compiler.syntax.tree.NameReferenceNode;
import io.ballerina.compiler.syntax.tree.NodeVisitor;
import io.ballerina.compiler.syntax.tree.SimpleNameReferenceNode;
import io.ballerina.compiler.syntax.tree.SyntaxTree;
import io.ballerina.projects.Document;
import io.ballerina.projects.DocumentId;
import io.ballerina.projects.Module;
import io.ballerina.projects.ModuleId;
import io.ballerina.projects.Package;
import io.ballerina.projects.plugins.ModifierTask;
import io.ballerina.projects.plugins.SourceModifierContext;

/**
 * Analyzes a Ballerina module init function.
 */
class GenerateFunctionAnalysisTask implements ModifierTask<SourceModifierContext> {
    @Override
    public void modify(SourceModifierContext modifierContext) {
        Package currentPackage = modifierContext.currentPackage();
        if (modifierContext.compilation().diagnosticResult().errorCount() > 0) {
            return;
        }

        for (ModuleId moduleId : currentPackage.moduleIds()) {
            Module module = currentPackage.module(moduleId);

            for (DocumentId documentId: module.documentIds()) {
                Document document = module.document(documentId);
                SyntaxTree syntaxTree = document.syntaxTree();
                ModulePartNode rootNode = syntaxTree.rootNode();
                SemanticModel semanticModel = modifierContext.compilation().getSemanticModel(module.moduleId());
                new MethodCallValidator(semanticModel, document).validateMethodCall(rootNode);
            }
        }
    }

    private static class MethodCallValidator extends NodeVisitor {
        private static final String GENERATE_METHOD_NAME = "generate";
        private final SemanticModel semanticModel;
        private final Document document;

        public MethodCallValidator(SemanticModel semanticModel, Document document) {
            this.semanticModel = semanticModel;
            this.document = document;
        }

        public void validateMethodCall(ModulePartNode memberNode) {
            visit(memberNode);
        }

        public void visit(MethodCallExpressionNode methodCallNode) {
            NameReferenceNode methodReferenceNode = methodCallNode.methodName();
            if (!(methodReferenceNode instanceof SimpleNameReferenceNode methodName)) {
                return;
            }

            if (!methodName.name().text().equals(GENERATE_METHOD_NAME)) {
                return;
            }

            semanticModel.symbol(methodCallNode.expression()).ifPresent(
                symbol -> {
                    semanticModel.visibleSymbols(document, methodCallNode.lineRange().startLine());
            });
        }
    }
}
